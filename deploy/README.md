# SigmaLoop — Cost-Optimized AWS Deployment

A pragmatic, **single-EC2 + S3/CloudFront** deployment tuned to fit the AWS
**$100 / 4-month** free-plan credit, with **CI/CD** that redeploys on every push
to `main`.

> This is the budget deployment. The serverless reference architecture
> (Step Functions + Lambda generation pipeline) lives in
> [`../Hosting SigmaLoop/README.md`](../Hosting%20SigmaLoop/README.md). That one
> is great but costs more than $25/mo to keep warm — out of scope for the credit.

---

## Architecture

```
                            sigmaloop.dpdns.org
                                    │ (CNAME)
   Browser ───────────────► CloudFront (TLS, ACM cert, free tier)
       │                          │
       │                          ▼
       │                  S3 bucket  (React build, private, OAC-locked)
       │
       │  api.sigmaloop.dpdns.org (A → Elastic IP)
       └──────────────► EC2 t3.small (Ubuntu 24.04)
                           │  nginx :443  (Let's Encrypt, auto-renew)
                           │     └─► 127.0.0.1:4000  Node API (Docker)
                           │                ├─► mongo            (internal)
                           │                └─► judge0-server    (internal)
                           └─ Docker Compose: api · mongo · judge0-server ·
                              judge0-workers ×2 · judge0-db · judge0-redis
```

**Why this shape:** the frontend is static, so S3+CloudFront serves it globally
for ~$0 (free tier) and keeps bandwidth off the EC2. Everything stateful/dynamic
(API, Mongo, Judge0) shares one small box. CloudFront and nginx both give free
TLS, so there is no load balancer to pay for.

---

## Cost (us-east-1, on-demand, 4 months)

| Item | /mo | ×4 |
|---|---:|---:|
| EC2 t3.small (2 vCPU / 2 GB) | $15.18 | $60.74 |
| EBS 30 GB gp3 | $2.40 | $9.60 |
| Public IPv4 (1 address) | $3.65 | $14.60 |
| S3 + CloudFront + ACM (free tiers) | ~$0.10 | ~$0.40 |
| Data transfer out (<100 GB/mo free) | $0 | $0 |
| **Total** | **~$21.3** | **~$85** |

≈ **$15 buffer** under the $100 credit.

**Cost levers if you need more room or more power:**
- **t3.medium (4 GB)** is far comfier for Judge0 + Mongo, but ~$30/mo → ~$121/4mo,
  over budget on its own. Smart move: run **t3.small day-to-day and resize to
  t3.medium only for your demo/grading window** (stop instance → change type →
  start; ~5 min, +~$1/day).
- **Stop the instance when idle** (nights/weekends pre-demo) — you only pay EBS
  + IPv4 while stopped (~$0.20/day).
- **Drop EBS to 20 GB** (−$3.2 over 4mo) if disk allows.
- **Offload Mongo to Atlas M0 (free forever, 512 MB)** to take ~400 MB of RAM
  pressure off the box and survive instance loss — set `DATABASE_URL` in
  `.env.prod` to the Atlas SRV string and remove the `mongo` service. (You asked
  for Mongo on the box, so the default keeps it there — this is just an option.)
- **IPv6-only** (no public IPv4, saves $14.6) is possible but many networks
  can't reach IPv6-only hosts — not worth the risk for a graded demo.

---

## Prerequisites

- AWS account on the free plan, AWS CLI configured locally (`aws configure`).
- Access to the **DigitalPlat FreeDomain** DNS panel for `sigmaloop.dpdns.org`.
- An SSH keypair for the EC2 box.

DNS records you'll create (in the DigitalPlat panel):

| Host | Type | Value | Purpose |
|---|---|---|---|
| `sigmaloop` | CNAME | `dXXXX.cloudfront.net` | frontend → CloudFront |
| `_<acm-token>` | CNAME | `_<acm-value>.acm-validations.aws` | validate the ACM cert |
| `api.sigmaloop` | A | `<EC2 Elastic IP>` | backend API |

---

## Part A — Frontend (S3 + CloudFront + ACM)

ACM certs for CloudFront **must** be in `us-east-1`.

```bash
REGION=us-east-1
BUCKET=sigmaloop-frontend                 # must be globally unique
DOMAIN=sigmaloop.dpdns.org

# 1) Private bucket (no public access; CloudFront reads it via OAC)
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# 2) Request the TLS cert (DNS-validated)
aws acm request-certificate --region "$REGION" \
  --domain-name "$DOMAIN" --validation-method DNS
# → copy the CNAME name/value from:
aws acm describe-certificate --region "$REGION" \
  --certificate-arn <arn> --query 'Certificate.DomainValidationOptions'
# Add that CNAME in the DigitalPlat panel; wait until status = ISSUED.
```

3) **Create the CloudFront distribution** (easiest in the console):
   - Origin: the S3 bucket, **Origin access: Origin access control (OAC)** →
     create OAC → CloudFront prints a bucket policy to paste back onto the bucket.
   - Viewer protocol policy: **Redirect HTTP → HTTPS**.
   - Default root object: `index.html`.
   - **Custom error responses:** map **403** and **404** → `/index.html` (200).
     This is the SPA fallback (so `/lesson/123` deep-links work).
   - Alternate domain name (CNAME): `sigmaloop.dpdns.org`; Custom SSL cert: the
     ACM cert above.

4) Point DNS: add `sigmaloop` **CNAME → `dXXXX.cloudfront.net`** in the panel.

5) First deploy (or just let CI do it — Part C):
```bash
cd ../Frontend
VITE_API_BASE_URL=https://api.sigmaloop.dpdns.org/api/v1 npm run build
aws s3 sync dist/ s3://$BUCKET --delete
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

---

## Part B — Backend (EC2)

1) **Launch** a `t3.small`, **Ubuntu 24.04 LTS (x86_64)**, 30 GB gp3, and
   **allocate + associate an Elastic IP**.

2) **Security group:**

   | Port | Source | Why |
   |---|---|---|
   | 22 | *your IP only* | SSH |
   | 80 | 0.0.0.0/0 | Let's Encrypt HTTP-01 + redirect |
   | 443 | 0.0.0.0/0 | API over TLS |

   Do **not** open 2358 (Judge0), 27017 (Mongo) or 5432 (Postgres) — they stay
   on the internal Docker network.

3) Point DNS: `api.sigmaloop` **A → Elastic IP**.

4) **Bootstrap the box** (handles Docker, swap, the Judge0 cgroup-v1 kernel
   flip, and cloning the repos):
```bash
scp deploy/ec2-bootstrap.sh ubuntu@<EIP>:~
ssh ubuntu@<EIP> 'bash ~/ec2-bootstrap.sh'   # phase 1 → asks you to reboot
ssh ubuntu@<EIP> 'sudo reboot'
ssh ubuntu@<EIP> 'bash ~/ec2-bootstrap.sh'   # phase 2 → clones repos
```

5) **Configure + start the stack:**
```bash
ssh ubuntu@<EIP>
cd ~/SigmaLoop/deploy
cp .env.prod.example .env.prod && nano .env.prod   # JWT_SECRET, AI keys, J0 pw
docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build
```

6) **TLS for the API:**
```bash
sudo cp ~/SigmaLoop/deploy/nginx-api.conf /etc/nginx/sites-available/sigmaloop-api
sudo ln -s /etc/nginx/sites-available/sigmaloop-api /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d api.sigmaloop.dpdns.org    # cert + auto-renew timer
```

7) **Verify:** `curl https://api.sigmaloop.dpdns.org/api/v1/health` → `200`.

---

## Part C — CI/CD (push to `main` → auto-deploy)

Because Backend and Frontend are **separate repos**, each owns its pipeline:

| Repo | Workflow | Trigger | What it does |
|---|---|---|---|
| `sigma-loop/Frontend` | `.github/workflows/deploy.yml` | push to main | build → `s3 sync` → CloudFront invalidation |
| `sigma-loop/Backend` | `.github/workflows/deploy.yml` | push to main | SSH → pull → rebuild & restart **api only** |
| `sigma-loop/SigmaLoop` | `.github/workflows/deploy-infra.yml` | push touching `deploy/**` | SSH → pull → `compose up -d` (recreates only changed services) |

**Restarting Judge0 "only on significant changes" — how it works:**
- A normal Backend push restarts just the `api` container → **zero Judge0
  downtime**.
- Judge0 restarts when you mean it to: put **`[judge0]`** (or `[infra]`) in the
  commit message, or run the Backend workflow manually with *recreate_all=true*,
  or change the Judge0 section of `docker-compose.prod.yml` (the infra workflow
  runs `compose up -d`, which recreates **only** services whose image/config
  changed).

### One-time GitHub setup

**Frontend repo** → Settings → Secrets and variables → Actions:
- *Variables:* `VITE_API_BASE_URL=https://api.sigmaloop.dpdns.org/api/v1`,
  `S3_BUCKET=sigmaloop-frontend`, `CLOUDFRONT_ID=<dist id>`
- *Secrets:* `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` — a **deploy-only IAM
  user** scoped to that bucket + that distribution (sample policy below).

**Backend repo** and **root repo** → Secrets:
- `EC2_HOST` (= `api.sigmaloop.dpdns.org` or the EIP), `EC2_USER` (`ubuntu`),
  `EC2_SSH_KEY` (a **dedicated** private key; add its public half to
  `~/.ssh/authorized_keys` on the box).

Minimal IAM policy for the frontend deploy user:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::sigmaloop-frontend" },
    { "Effect": "Allow",
      "Action": ["s3:PutObject","s3:DeleteObject"],
      "Resource": "arn:aws:s3:::sigmaloop-frontend/*" },
    { "Effect": "Allow",
      "Action": ["cloudfront:CreateInvalidation"],
      "Resource": "*" }
  ]
}
```
> More secure upgrade: replace the static AWS keys with GitHub OIDC
> (`aws-actions/configure-aws-credentials` + an IAM role trusting GitHub's OIDC
> provider) so there are no long-lived secrets. Static keys are fine to start.

---

## Operations cheat-sheet

```bash
# on the box
cd ~/SigmaLoop/deploy
docker compose -f docker-compose.prod.yml --env-file .env.prod ps        # status
docker compose -f docker-compose.prod.yml --env-file .env.prod logs -f api
docker stats --no-stream                                                 # RAM check
free -h                                                                  # swap usage
docker compose -f docker-compose.prod.yml --env-file .env.prod restart judge0-server
```

### Troubleshooting

- **Judge0 returns errors / won't start, "cgroup" in logs** → the box is still on
  cgroup v2. Re-run `ec2-bootstrap.sh`, reboot, confirm with
  `ls /sys/fs/cgroup` (you should see `memory/`, `cpuset/`… not `cgroup.controllers`).
- **Box gets sluggish / containers OOM-killed** (`dmesg | grep -i oom`) → the
  2 GB ceiling. Confirm swap is on (`free -h`), drop Judge0 `COUNT` to 1, or
  resize to t3.medium for the demo.
- **Frontend loads but API calls fail with a CORS/mixed-content error** → the
  build must use the **https** API URL (`VITE_API_BASE_URL`), and the API must be
  served over TLS (step B6). Mixed http→https content is blocked by browsers.
- **Deep links (e.g. `/lesson/123`) 404 on refresh** → add the 403/404 →
  `/index.html` custom error responses in CloudFront (Part A step 3).
- **`git pull --ff-only` fails in CI** → someone committed on the box; reset with
  `git fetch && git reset --hard origin/main` there.

## Files in this folder
- `docker-compose.prod.yml` — the full backend stack (one box).
- `.env.prod.example` — copy to `.env.prod` on the box (never committed).
- `ec2-bootstrap.sh` — provisions a fresh Ubuntu box (Docker, swap, cgroup v1).
- `nginx-api.conf` — API reverse proxy; certbot adds TLS.
- `deploy-frontend.sh` — manual frontend build + push (CI does this on push).

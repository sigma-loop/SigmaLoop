# Chapter 6 — Authentication, Authorization & Security

This chapter covers how a request proves its identity, how the system decides what that
identity may do, and the platform's defense-in-depth posture — including, honestly, the
places where the posture is weaker than it should be.

## 6.1 Authentication: JWT, end to end

SigmaLoop uses stateless **JWT Bearer** authentication.

**Issuance.** On register and login (`auth.controller.ts`), the password is verified
against a bcrypt hash (cost 10, minimum length 6), then a token is signed:

```ts
jwt.sign({ id, email, role }, config.jwt.secret, { expiresIn: '7d' })
```

The payload is small and self-contained: `{ id, email, role }`. The secret comes from
`config.jwt.secret`; in production the config throws if `JWT_SECRET` is unset, and in
development it falls back to a well-known placeholder.

**Verification.** The `authenticate` middleware (`middlewares/auth.middleware.ts`)
parses `Authorization: Bearer <token>`, verifies it, and then does one more thing most
JWT setups skip — it **re-loads the user from the database**:

```ts
const decoded = jwt.verify(token, config.jwt.secret) as { id; email; role }
const user = await User.findById(decoded.id)
if (!user) { res.status(401).json(error('User not found', 'UNAUTHORIZED')); return }
req.user = { id: decoded.id, email: decoded.email, role: decoded.role }
next()
```

> 💡 **Design Note — the per-request DB lookup is a deliberate revocation lever.** A
> pure JWT is valid until it expires, even if the account is deleted or banned.
> Re-checking `User.findById` on every authenticated request means a deleted user is
> locked out *immediately*, at the cost of one indexed lookup per call. For a tutoring
> app at classroom scale this is a good trade; at very high scale it becomes a caching
> candidate.

`req.user` is typed globally via `types/express.d.ts` as `{ id, email, role }`, so every
controller can read it without re-parsing.

There is also **`optionalAuthenticate`**: same parsing, but a missing or invalid token
simply proceeds *unauthenticated* (`req.user` undefined) rather than rejecting. Exactly
one route uses it — `POST /chat/guest` — so the public mentor works for signed-in and
anonymous visitors alike.

## 6.2 Authorization: two roles, one guard

There are exactly two roles, in `constants/roles.ts`:

```ts
export const ROLES = { STUDENT: 'STUDENT', ADMIN: 'ADMIN' }
```

Authorization is a thin guard, `authorize(...roles)`, that must run *after*
`authenticate`:

```ts
export const authorize = (...roles) => (req, res, next) => {
  if (!req.user) return res.status(401).json(error('Unauthorized', 'UNAUTHORIZED'))
  if (!roles.includes(req.user.role)) return res.status(403).json(error('Forbidden', 'FORBIDDEN'))
  next()
}
```

The entire `/admin` group is protected by a single router-level
`router.use(authenticate, authorize(ROLES.ADMIN))`, so every admin endpoint is
ADMIN-only by construction rather than per-route. Everywhere else, a valid STUDENT (or
ADMIN) token is sufficient — finer access control is handled by **ownership**, not roles.

## 6.3 Ownership: the real access-control model

Because all content is per-user, the meaningful authorization question is almost never
"what is your role?" but "do you own this?". The answer is enforced two ways:

1. **Every read filters by `userId`.** Controllers query
   `Model.findOne({ _id, userId: req.user.id })`. If you don't own it, the query returns
   nothing.
2. **A miss returns `404`, not `403`.** This is consistent across the codebase
   (`execution`, `math`, `mcq`, `lesson`, `course`, `challenge`, and the curriculum job
   poll all do it).

> 💡 **Design Note — why 404 instead of 403.** A `403 Forbidden` confirms that a
> resource *exists* but isn't yours — an information leak (an attacker could enumerate
> valid course ids). Returning `404 Not Found` for both "doesn't exist" and "exists but
> not yours" reveals nothing. It costs a little semantic precision for a real privacy
> gain, and the trade is taken everywhere.

The autonomous mentor inherits this model at the tool layer: **every** mentor tool runs
its Mongo query with `{ userId: ctx.userId }`, so the agent literally cannot read or
mutate another learner's data, no matter what the model is prompted to do (Chapter 13).

## 6.4 Answer secrecy: the serialization chokepoint

A subtler authorization problem: the *content* of a challenge contains the answer. A
student who owns a challenge may read it — but must not see the reference solution, the
hidden test cases, the MCQ correct flags, or the math canonical solution.

This is solved with a single function, `utils/challengeSerializer.ts`, through which
**every** student-facing challenge read passes:

- **PROGRAMMING:** the student gets `description`, `starterCodes`, and only the
  **non-hidden** test cases. `solutionCodes` and hidden cases are admin-only.
- **MATH:** the student gets `problemLatex` and `mathRunLimit`.
  `canonicalSolutionLatex` and `gradingRubric` are admin-only.
- **MCQ:** the student gets `prompt`, `allowMultiple`, and options as `{ id, text }`
  only. `isCorrect`, per-option `explanation`, and `overallExplanation` are admin-only.

Only an admin ever sees the full shape; a student never does, even for their own
content. Correctness data reaches a student only through the **grading endpoints**
(`/mcq/submit`, `/math/submit`) — never through a read. Centralizing this in one
function means there is one place to audit, and no controller can accidentally leak an
answer by serializing a raw Mongoose document.

## 6.5 The platform's defensive surface

Beyond auth, the app layer (`app.ts`) provides:

- **Manual CORS** that reflects the request origin, allows credentials, and
  short-circuits `OPTIONS` with `204`.
- **Body-size parsing** via `express.json()` (a place to add an explicit limit).
- A **request logger** and a JSend **404** and **500** handler so nothing leaks a stack
  trace to the client (the error body carries `err.message` in `details`, not the
  stack).

The AWS proposal (Chapter 17) layers the production-grade controls on top: **WAF**
(managed common rules + rate-based), **Secrets Manager** with rotation, **KMS**
encryption for every data store, **TLS-only** S3 policies, **CloudTrail** + **GuardDuty**,
and a scoped, least-privilege VPC. The mentor's prompt-injection risk is mitigated by
the ownership-scoped tool layer (the agent can only touch the caller's data) plus output
moderation and a token cap.

## 6.6 Known weaknesses (read before deploying publicly)

A documentation set earns trust by naming the gaps. As of this writing:

> ⚠️ **Implementation Note — rate-limiting is disabled.** All three limiters
> (`apiLimiter`, `authLimiter`, `executionLimiter`) are pass-through no-ops. Login
> brute-forcing, AI-cost abuse, and Judge0 flooding are currently unthrottled at the app
> layer. The intended tiers (100/15min general, 5/15min auth, 20/15min execution) are
> written but commented out. **Re-enable these before any public deployment**, or rely on
> WAF rate rules at the edge.

> ⚠️ **Implementation Note — JWT expiry is hard-coded.** The controllers sign tokens
> with a literal `expiresIn: '7d'`, even though `config.jwt.expiresIn` (admin-tunable)
> exists. Changing `JWT_EXPIRES_IN` at runtime does **not** affect newly issued tokens
> today; the literal must be changed to read the config value.

> ⚠️ **Implementation Note — dev secrets are committed.** `Backend/.env.judge0` ships
> with `judge0password` / `judge0redispassword`, the Compose file has a default
> `JWT_SECRET=dev-secret-change-me`, and the Qwen hint URL is a checked-in ngrok tunnel.
> These are fine for local development but are **never** to be used in production — the
> AWS plan moves all secrets to Secrets Manager + KMS.

> ⚠️ **Implementation Note — the frontend API URL is hard-coded.** The Axios client in
> `Frontend/src/services/api.ts` hard-codes `http://localhost:4000/api/v1` rather than
> reading `VITE_API_BASE_URL`. A production build must change this line (Chapter 8).

None of these are subtle to fix; they are listed so they are *fixed deliberately* rather
than discovered in production. With identity and trust established, Chapter 7 turns to
how the running system is configured — including live, without a redeploy.

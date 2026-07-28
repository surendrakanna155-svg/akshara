# Payments — what is actually implemented (code-verified, 2026-07-28)

> Every answer below was read out of the code, not inferred.

## Direct answers

| Question | Answer |
|---|---|
| **Offline only?** | **In practice, yes.** `manual_provider.ts` is the only provider that can complete anything today, and it settles out of band through the finance maker–checker flow. |
| **Razorpay integrated?** | **Yes — the backend is complete.** `razorpay_client.ts`, `razorpay_provider.ts`, `razorpay_config.ts`, order creation, payment-signature verification, and a webhook handler with enforced `X-Razorpay-Signature` checking all exist and are tested. **It is inactive**, not missing. |
| **UPI integrated?** | **No.** UPI exists only as a *label* in the client's method picker (`PaymentMethod.upi` → "UPI", a QR icon). There is no UPI intent, no PSP handoff, no collect request. If Razorpay were enabled, UPI would arrive as one of its methods — it is not a separate integration. |
| **Gateway partially implemented?** | **Backend complete, client half absent.** There is **no payment SDK in `pubspec.yaml` at all** — no Razorpay, PayU, Cashfree, Stripe, Paytm or PhonePe. |
| **Mock implementation?** | **No — it was removed.** PRA-P0-02 deleted `submitMockPayment`, which used to fabricate a `txn_<millis>` reference and post a **real receipt against a real invoice for money nobody paid**. |
| **Sandbox?** | **No.** Stub mode is not Razorpay test mode. No test credentials are wired. |
| **Production ready?** | **The safety model is; the capability is not.** No money can move — and, just as importantly, **no fake receipt can be produced.** |

## What switches it on

```
razorpay_config.ts
  enabled = Boolean(RAZORPAY_KEY_ID && RAZORPAY_KEY_SECRET) && !RAZORPAY_STUB_MODE
  RAZORPAY_STUB_MODE defaults to "true"
```

So live payments need **all three**: a key id, a key secret, and `RAZORPAY_STUB_MODE=false`.
While stubbed, webhook capture is refused outright (ICA-A5) unless
`RAZORPAY_ALLOW_UNSIGNED=true`, which exists only for local development.

## What a parent sees today

Tapping **Pay Now** creates a real payment intent, then stops at
`PaymentFlowPhase.pendingGatewayVerification` and shows:

> **Online payment not enabled yet** — This school has not enabled an online
> payment gateway, so the fee could not be charged. **You have NOT been charged.**
> Please pay at the school office or try again later.

That is honest and correct. No receipt, no success ceremony, no dues cleared.

## Recommendation for Version 1 — ship offline collection, disclosed

**Do not chase a live gateway for V1.** Reasons:

1. **Razorpay onboarding is not an engineering task.** It needs a registered
   business entity, PAN, bank account and KYC. That sits on the same
   owner-dependent critical path as the Play Console account.
2. **The safety model is already correct and audited.** Nothing about enabling a
   gateway later requires re-architecting; the verified-signature path is built
   and waiting.
3. **Counter collection already works end to end.** Office staff record fees,
   issue numbered receipts, and are protected by maker–checker and day-close
   locks. This is how most Indian schools actually collect money.

**One change worth making before the demo:** the parent's CTA currently reads as
an online-payment button and only reveals the truth *after* it is tapped. Better
to label it honestly up front — "Pay at school" / "Get payment reference" — so no
parent is walked into a dead end. That is a copy and routing change, not a
gateway change.

**What to say to a school in the demo:** *"Fee collection at the office is live
today, with audited receipts. Online payment is built and waiting on the
school's payment-gateway account — we switch it on with credentials, not with a
new release."* That is true, and it is a stronger position than a competitor
demoing a payment flow that silently fails.

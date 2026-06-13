# OmniMind Chat Latency — Notes & Fix Plan

## What we observed
- Backend `/chat` calls Groq model `llama-3.1-8b-instant`.
- Even after warmup, typical LLM latency is ~1.5–1.8s per turn (from server logs).
- Additionally, backend runs crisis classifier (best-effort) that can add up to ~12s timeout; in practice it likely fails/times out sometimes.

## Likely causes of “slow / not immediate” UI
1. **LLM network + inference**: Groq response time is inherently ~1–2 seconds.
2. **Crisis classifier delay**: may be blocking parts of the request path (it waits up to 12s).
3. **No streaming**: response is returned only after the full model finishes.
4. **Flutter UX waits for full response**: typing dots show, but message rendering happens after response.

## Recommended fixes (highest impact first)

### 1) Make crisis classification non-blocking (do not await timeout)
- Currently: backend runs crisis classifier in a thread and calls `future.result(timeout=12)`.
- Change to:
  - Either: run classifier asynchronously and return chat response immediately
  - Or: reduce timeout to ~1–2 seconds and/or skip if rag_ctx is empty.

### 2) Add streaming support (optional but biggest UX improvement)
- Use Groq streaming and return partial tokens.
- Requires changing `/chat` to SSE/websocket (or chunked HTTP).
- Flutter: update ChatProvider/UI to append tokens as they arrive.

### 3) Cache retrieval results
- If `rag.retrieve()` is expensive, cache by message embedding hash or input text.

### 4) Provide earlier “draft” reply
- For non-crisis: return quick template acknowledgment first, then replace with full LLM reply.
- Requires two-step protocol or background job.

## Immediate “quick win” patch to implement now
- Reduce crisis classifier timeout from 12s to 1–2s.
- If it doesn’t finish, continue without it (already best-effort, but currently it still blocks up to the timeout).

## How to test
- Call `POST /chat` repeatedly with the same messages.
- Measure `latency_ms` from response and end-to-end time from Flutter.
- Confirm crisis classifier warnings disappear and `latency_ms` stabilizes.


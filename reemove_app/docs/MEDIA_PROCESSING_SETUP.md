# Media processing setup

ReeMove accepts images directly and routes videos through an external processing service. The service may be implemented with Cloud Run, a managed transcoder, or another private worker, but it must obey this contract.

## Required Firebase parameters and secret

Configure these for every non-emulator project:

```bash
firebase functions:secrets:set MEDIA_PROCESSOR_SECRET
firebase functions:config:set \
  media.processor_url="https://YOUR_PROCESSOR_ENDPOINT" \
  media.processor_callback_url="https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/completeMediaProcessing"
```

The source uses typed Functions parameters named:

- `MEDIA_PROCESSOR_URL`
- `MEDIA_PROCESSOR_CALLBACK_URL`
- `MEDIA_PROCESSOR_SECRET`

Use the parameter mechanism supported by the deployed Firebase CLI/runtime rather than committing values to source control. Ensure the callback URL points to the deployed `completeMediaProcessing` HTTP Function.

## Dispatch request

The processor receives an authenticated JSON `POST`:

```json
{
  "assetId": "ASSET_ID",
  "ownerId": "USER_UID",
  "inputStoragePath": "content/USER_UID/DRAFT_ID/ASSET_ID/file.mp4",
  "callbackUrl": "HTTPS_CALLBACK",
  "outputPrefix": "processed/USER_UID/ASSET_ID/"
}
```

Header:

```text
Authorization: Bearer MEDIA_PROCESSOR_SECRET
Content-Type: application/json
```

## Processor responsibilities

- Fetch only the supplied Storage object.
- Validate and transcode video to mobile-safe renditions.
- Strip unsafe metadata.
- Enforce duration, dimensions, bitrate, codec, and output-size policy.
- Generate a poster/thumbnail.
- Write every output below the supplied `outputPrefix`.
- Never accept an arbitrary output path from an end user.
- Retry callback delivery idempotently.
- Keep the bearer secret in the platform secret manager.

## Completion callback

Send an authenticated JSON `POST` to `callbackUrl`:

```json
{
  "assetId": "ASSET_ID",
  "outputStoragePath": "processed/USER_UID/ASSET_ID/video.mp4",
  "thumbnailStoragePath": "processed/USER_UID/ASSET_ID/poster.jpg",
  "width": 1080,
  "height": 1920,
  "durationMs": 12000
}
```

The callback verifies the job, owner-derived output prefix, Storage object metadata, and shared secret. It never trusts a client-provided owner ID.

## Recommended production outputs

- H.264/AAC MP4 baseline for broad compatibility.
- At least one mobile portrait rendition for reels.
- Bounded 720p/1080p output according to source quality.
- JPEG/WebP poster image.
- Server-measured duration and dimensions.
- Optional HLS/DASH can be introduced later behind the same `MediaAsset` contract.

## Operations

Alert on:

- queued jobs older than five minutes
- repeated dispatch failures
- callback authentication failures
- invalid output prefixes
- failed jobs after five attempts
- unusual upload sizes or MIME mismatches
- processing latency percentiles

The scheduler does nothing until both processor URLs are configured, so development environments can publish image content without a video service.

# D05.2 native motion verification

Full DeviceInteraction screenshots/hierarchies, unchanged, exact reference iPad
07C2B017 and phone9F90CD21, iOS27.2, normal text, disposable A-progress secondleg.
Candidateb0ff6b3 plus final D05.2 application patch, built00:39:45; later changes
were tests/docs only. Root installed that same app on phone before verification.

| Device | Normal fast | Native Reduce Motion ON | Same fast / slow1° | Restored OFF | Slow north / later stable |
| --- | --- | --- | --- | --- | --- |
| iPad |176→117 at00:52:06|00:52:47|117→085 /085→084 at00:53:02/06|00:53:19|084→357 /357 at00:53:43/46|
| Phone |176→118 at07:41:37|07:42:09|118→086 /086→085 at07:42:15/19|07:42:34|085→358 /358 at07:42:41/44|

Same camera value remained exact. Normal fast swipe: top arc80pt right/down over
0.1s. Reduced Motion removes additional coast in code; native ON/OFF values and
actual selection changes are evidenced here. Human gesture feel remains unchecked.

Stop-on-contact timing remains unverified. Multi-lift `mt` sequences produced no
movement; supported chained commands matched uninterrupted travel. Screen recording
`/private/tmp/d052-phone-contact.mp4` and OCR `/private/tmp/d052-contact-ocr.txt`
show bounded settling, but do not show the second touch's delivery time. They do
not establish cancellation timing. No successful timing claim is inferred from
code inspection, final values, or these screenshots. The matrix preserves this
limitation for owner hands-on acceptance. No native Motion setting was left changed.

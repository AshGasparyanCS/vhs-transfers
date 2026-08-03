# VHS transfer business, context primer

Drop this in a new Claude chat on any machine to catch it up. Style note, same as
the homelab primer: no em dashes ever, commas or hyphens instead, keep it casual.

Last updated: 2026-08-02

## What this is

A small side business converting people's VHS and VHS-C tapes to digital files,
run out of Los Angeles. One person operation.

**The customer drops off and picks up.** This changed twice: it started as free
door to door pickup, became "contact for pickup and return", and is now
customer drop off. The site says "Drop Off & Pick Up" and step 2 reads "we pick
a time and place". The differentiator is still that tapes stay local and are
never mailed, which mail-in competitors cannot match, but the driving is no
longer being offered.

**Open question: where do people actually drop off?** The site deliberately does
not publish an address and should not, this is a home operation. It currently
says a time and place gets arranged, which is fine to start but will get repetitive
over the phone if volume grows.

Owner: Ash Gasparyan, GitHub `AshGasparyanCS`.

## Contact details as published

- Phone **(818) 732-8094**, this is a Google Voice number, not the personal cell.
  Deliberate choice because the site is public and gets scraped.
- Email **ashgasparyan04+vhs@gmail.com**, a Gmail plus-address so business mail
  can be filtered from personal. It still lands in the `ashgasparyan04@gmail.com`
  inbox, the `+vhs` tag just makes the source obvious and filterable.
- Service area: Los Angeles and surrounding

## The website

- **Live**: https://ashgasparyancs.github.io/vhs-transfers/
- **Repo**: https://github.com/AshGasparyanCS/vhs-transfers (public, required for free Pages)
- **Local working copy**: `~/vhs-site/` on the OptiPlex (`192.168.4.35`, user `plex`)

Files in the repo:

| File | What it is |
| --- | --- |
| `index.html` | The whole site. Single self-contained page, one inline script for the estimator, no external requests |
| `intake-form.html` | Printable tape intake and receipt form, print to PDF with Ctrl+P |
| `README.md` | Deploy and update instructions |
| `Verify-Drive.ps1` | PowerShell drive verification, see below |
| `New-Delivery.ps1` | PowerShell uploader, makes the 14 day customer link |
| `PROJECT-PRIMER.md` | This file |

### Updating the site

```bash
cd ~/vhs-site
# edit index.html
git add -A && git commit -m "what changed" && git push
```

Live within about a minute. Can also be edited directly in the GitHub web editor
from any machine, which is the easier path when away from the OptiPlex.

### Two things to know about the repo setup

- **Git identity is repo-local, not global.** It is set to the GitHub noreply
  alias `124556852+AshGasparyanCS@users.noreply.github.com` so the real email
  never lands in public commit history. If you re-clone this repo somewhere else,
  set that again or the real email leaks into commits.
- **`gh` is installed at `~/.local/bin/gh`** on the OptiPlex (v2.97.0, installed
  as a plain binary, no sudo). Already authenticated as `AshGasparyanCS` with
  `repo` and `workflow` scopes.

Pages was enabled via API, not the web UI:
```bash
gh api -X POST repos/AshGasparyanCS/vhs-transfers/pages \
  -f 'source[branch]=main' -f 'source[path]=/'
```

## Pricing, and why it is what it is

**Per tape, any length up to 6 hours:**

| Tapes | Each |
| --- | --- |
| 1 to 4 | $20 |
| 5 to 9 | $17 |
| 10+ | $15 |

**Disc archiving** (home-burned discs only, same copyright rule as tapes):

| Type | Typical size | 1 to 9 | 10+ |
| --- | --- | --- | --- |
| CD | 0.3 to 0.7 GB | $8 | $6 |
| DVD | 2 to 8.5 GB (4.7 single layer, 8.5 dual) | $10 | $8 |

Discs are much faster than tape since they copy at drive speed rather than
realtime, which is why they are cheaper per unit despite holding more.

**Delivery is USB drive only.** The site has a single combined "Getting your
files back" table: bring-your-own comes first at no charge and points people at
the estimator to work out the size they need, then the five supplied sizes.
These were two separate tables and were merged deliberately, do not split them
again.

| Drive | Cost each | Sells for | Margin | Holds | Fits |
| --- | --- | --- | --- | --- | --- |
| 16GB | $4.90 | $10 | $5.10 | ~10 hrs | 2-3 tapes |
| 32GB | $6.50 | $14 | $7.50 | ~20 hrs | ~5 tapes |
| 64GB | $9.00 | $18 | $9.00 | ~40 hrs | ~10 tapes |
| 128GB | $13.00 | $25 | $12.00 | ~85 hrs | ~20 tapes |
| 256GB | $25.00 | $45 | $20.00 | ~170 hrs | ~40 tapes |

All five are priced at roughly double cost, so the margin is consistent and no
size is a trap. The small sizes exist so a one or two tape customer is not being
sold a $18 drive on top of a $20 job, which looked bad and was the reason the
full range went on.

### The reasoning, do not undo this without understanding it

Walmart and most mail-in services charge roughly **$15 for the first 30 minutes
plus $6 per additional 30 minutes, per tape**. That works out to:

| Tape length | Them | Us |
| --- | --- | --- |
| 2 hours | $33 | $20 |
| 4 hours | $57 | $20 |
| 6 hours | $81 | $20 |

Their model punishes long tapes, and most family tapes were recorded in EP/SLP
mode which runs 4 to 6 hours. Flat rate wins everywhere and wins enormously on
the common case. It is also far easier to advertise. "Flat $20 per tape no matter
how long" fits in a headline, "$4.50 per half hour" does not.

The marginal cost of a 6 hour tape versus a 2 hour tape is basically just
unattended machine time, so flat rate is honest, not a loss leader.

### Flash drive economics

Bulk sources found:

| Drive | Pack | Cost each | Per GB |
| --- | --- | --- | --- |
| 16GB | 10 pack, $49 | $4.90 | $0.31 |
| 32GB | 10 pack, $65 | $6.50 | $0.20 |
| 64GB | 5 pack, $45 | $9.00 | $0.14 |
| 128GB | 5 pack, $65 | $13.00 | $0.10 |
| 256GB | 3 pack, $75 | $25.00 | $0.098 |

A 5 pack of 32GB at $37 was also seen, which is worse per unit than the 10 pack.

Per GB the big drives win decisively, $0.10 for the 128GB against $0.31 for the
16GB. **But all five sizes are stocked and listed anyway**, because per-GB value
is the wrong metric for a small order. A customer with one 2 hour tape needs
about 2.8GB, and quoting them $18 for a 64GB drive on top of a $20 job made the
drive cost as much as the service. The small sizes exist to serve that customer,
not to be good value per GB.

Do not "optimize" this by removing the small drives again, it was considered and
rejected deliberately.

Sizing math: digitized video runs about **1.4GB per hour**, and tape estimates
assume a typical 4 hour recording. Long-play tapes run 6 hours, so size up when
a customer says their tapes are the long kind.

An earlier $95 for 5 x 128GB listing was rejected as overpriced at $19 each.

**Counterfeit drives are the real risk here.** Fake flash drives report a large
capacity to the OS but physically hold far less, write "successfully", then
silently corrupt. For this business that means handing someone the only copy of a
dead relative's wedding and having it be garbage six months later. Buy SanDisk,
Samsung, PNY or Kingston from Amazon's own listing, not third party sellers, and
verify every drive on arrival:

**The work happens on a Windows laptop, so `f3` is not an option**, it is Linux
only. Use `Verify-Drive.ps1` in this repo instead:

```powershell
# from the folder containing the script, in PowerShell
.\Verify-Drive.ps1 -DriveLetter E
```

It fills the drive with random data recording a SHA256 per chunk, makes you
unplug and replug to defeat Windows write caching (skipping that step lets a fake
drive pass by serving reads from RAM), then reads everything back and compares.
Exits 0 on pass, 1 on fail.

If PowerShell execution policy blocks it:
`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

**H2testw** is the long established alternative and does the same job with a GUI.
Either is fine. Run it once per drive when a pack arrives, not per customer.

## PAL / SECAM tapes

**The current VCR is NTSC only and cannot play PAL or SECAM tapes.** This is not
a tracking issue, the formats differ in line count (525 vs 625), frame rate
(29.97 vs 25) and tape speed, so an NTSC deck gets no lock at all.

Cassettes are physically identical, so there is no way to spot one by looking.
The site FAQ now asks anyone with overseas tapes to say so up front.

Playing them needs a multi-system "world" VCR (Panasonic NV-J700AM, Samsung
SV-5000W, AIWA HV-MX100 and similar), none still manufactured, roughly $150 to
$400 used. Two things to check when buying: that it outputs native PAL rather
than converting to NTSC internally (conversion loses quality), and that the
capture device accepts 576i/25fps input.

**Decision (Aug 2026): deferred.** Not buying a multi-system deck for now. If
PAL or SECAM requests start coming in regularly, revisit then. Until that happens
the site FAQ handles it by asking people to flag overseas tapes up front.

**It remains a real opportunity, not just a problem.** LA has very large diaspora
communities and almost nobody offers PAL or SECAM conversion locally. It could
justify a premium rate around $30 to $35 per tape, paying back the deck in about
ten tapes. Worth revisiting once the NTSC side is running smoothly.

## The estimator on the site

`index.html` has a calculator at `#estimate` that sizes the drive and totals the
cost from tape / CD / DVD counts. Pure vanilla JS in a script tag at the bottom,
no dependencies, no network calls, runs entirely client side.

Assumptions live in constants at the top of that script:

- `GB_PER_TAPE_HOUR = 1.4`
- `GB_PER_CD = 0.7` (a completely full disc, the maximum a CD holds)
- `GB_PER_DVD = 4.7` (a full single-layer disc)
- Drive usable capacity is about 93% of nominal, and the picker leaves a further
  10% headroom so nobody lands at 100% full
- The `DRIVES` array holds all five sizes. Anything over what a 256GB drive can
  take falls through to a "get in touch" message rather than a price

**There is no tape length question.** Customers almost never know how long their
recordings run, so asking was friction for an answer that would be guessed anyway.
Every tape is assumed to be `AVG_TAPE_HOURS` (4). That constant is written into
the visible disclaimer at runtime via the `q-avg` span, so changing the number in
one place updates the on-page text too and the two cannot drift apart.

**Everything rounds up on purpose.** The per-item sizes sit at the pessimistic
end of each range and the total is passed through `Math.ceil`. The estimator
states its assumptions in plain text under the total. Note that tape length only moves the drive recommendation, not
the price, since the tape rate is flat regardless of length, so erring long costs
the customer nothing on the conversion itself.

The headroom is deliberate and slightly conservative. Ten 4 hour tapes come to
56GB, which technically fits a 64GB drive but would leave it 94% full, so the
calculator recommends 128GB instead. Sizing up is the cheap mistake, sizing down
means a second trip across LA.

**If any price changes, it must be updated in three places**: the pricing tables
in `index.html`, the `tapeRate` / `cdRate` / `dvdRate` functions in that script,
and `intake-form.html`. There is no shared source of truth, so grep for the number.

## Delivery: the 14 day Nextcloud link

Free delivery option on the site. Files go to Nextcloud, the customer gets a
private link, the link dies after 14 days.

**Account details, all verified working as of Aug 2026:**

- Nextcloud account username is **`Memory Archives`**, with a space. It is NOT
  `deliveries`. The space must be URL encoded as `Memory%20Archives` in every
  WebDAV path or you get a 401 that looks like a wrong password.
- Quota is unlimited on that account. The NAS has ~16TB and is nearly empty.
- Auth is an app password, stored on the OptiPlex at `~/.vhs-nextcloud-creds`,
  mode 600. **Quote the values in that file**, the space in the username breaks
  `source` otherwise, which is a confusing failure because the old value silently
  stays set.

**The share URL needs rewriting, this is the important gotcha.** Nextcloud builds
the link from whatever host the API request arrived on. Uploading over the LAN
returns `https://192.168.4.125:30027/s/TOKEN`, which is useless to a customer.
The token is host independent, so split on `/s/` and rebuild the URL against
`https://cloud.173842069.xyz`. Verified: the rewritten link returns 200 publicly.

**Upload speed is not a constraint.** Measured 318 Mbps up, so a 20 tape order
(~90GB) uploads in about 40 minutes. Upload over the LAN address, not the public
one, to keep the traffic off the Cloudflare tunnel.

**Usage** (on the Windows laptop, config at `%USERPROFILE%\.vhs-delivery.json`):

```powershell
.\New-Delivery.ps1 -Customer "Sarkisian" -Path "D:\Captures\Sarkisian"
.\New-Delivery.ps1 -List      # what is on the server and when each link dies
.\New-Delivery.ps1 -Cleanup   # delete folders whose links already expired
```

**Expiry disables the link, it does not delete the files.** Without running
`-Cleanup` periodically the 16TB slowly fills with old orders. Worth a monthly
reminder.

## Workflow and the intake form

`intake-form.html` prints to a 2 page form. Page 1 is the main intake, 12 tape
rows plus terms and signatures. Page 2 is a continuation sheet for orders past
12 tapes, only print when needed.

**Print two copies of page 1**, one for the customer and one for the business,
and both parties sign both. There is a second signature block at the bottom for
when the tapes are returned and payment is taken.

Writing down every tape together at drop off costs nothing, reassures people a lot,
and protects against someone later believing they handed over a tape they didn't.

Terms on the form cover: all tapes returned, quality reflects the original, no
charge for unplayable tapes, no commercial or copyrighted tapes, liability capped
at the conversion fee, files held 30 days then deleted.

## Hardware and the real constraint

A VCR and a laptop. The work is **not** done on the OptiPlex, that is just where
the website lives.

**Capacity, not demand, is the bottleneck.** Capture is realtime. Ten six hour
tapes is 60 hours of VCR time, roughly three days running continuously, and the
capture machine is occupied throughout. The site currently promises "most orders
in under a week", which is honest for one or two customers at a time but breaks
down if three people call the same week.

**Decision (Aug 2026): no second VCR** unless traffic genuinely picks up. That
makes the "most orders in under a week" line on the site the weak point, since
with one deck a 20 tape order of long tapes is over 100 hours of capture, which
is more than four days running continuously and that assumes the machine is never
needed for anything else. Either soften that line or be ready to quote longer
turnarounds by phone. **This is still unresolved on the live site.**

## Open tasks

1. **Verify the flash drives with `f3probe`** when the 5 pack arrives. A script
   to loop every plugged-in drive and print pass/fail was offered but not written yet.
2. **Resolve the capacity question** above, second VCR or softer promise.
3. **Marketing.** Nextdoor is likely the single best channel given the local
   angle and the demographic, one post per neighborhood. Facebook local groups
   second. The site will not rank in search, a brand new github.io subdomain has
   no authority, so essentially all traffic will be from shared links. The Open
   Graph tags are already set so shared links preview correctly.
4. **Consider a real domain** eventually. GitHub Pages supports custom domains
   free. `ashgasparyancs.github.io/vhs-transfers` is fine but a real name is
   better on a flyer. About $10 to $15 a year.
5. **Business name.** There isn't one yet, the site is unbranded. Fine for now.

## Things already decided, do not re-litigate

- Flat rate per tape, not per hour. See reasoning above.
- **Customer drops off and picks up.** Do not put "I collect from your door" or
  "free pickup" back on the site, both were removed deliberately. The selling
  point is that tapes stay local and are never mailed, not that anyone drives.
- Google Voice number rather than personal cell, because the site is public.
- Commercial and copyrighted tapes are declined, this is standard industry
  practice and it is on both the site FAQ and the intake form.
- 128GB as the single drive size.
- Repo named `vhs-transfers` rather than taking the `ashgasparyancs.github.io`
  bare URL slot, which is being kept free for something personal.
- **No free download link delivery option.** This was proposed twice and rejected
  both times. Hosting customer video files on the personal Nextcloud is not
  wanted. Do not suggest it again.
- **No burning output to DVD.** Removed deliberately. Authoring a playable
  DVD-Video disc is real work per order and a data disc full of MP4s would
  disappoint anyone expecting to put it in a DVD player, so the option is gone
  rather than ambiguous. **Delivery is USB drive only.**
  Note that DVDs still appear on the site as an INPUT, the disc archiving service
  where a customer's own home-burned discs get copied to files. Do not confuse
  the two and do not remove that.
- All four drive sizes stay on the site, see the drive section above.
- The competitor price comparison table was removed from the site on purpose.
  Inviting people to price shop framed the business as the budget option rather
  than the convenient local one, and staying local is the stronger pitch.

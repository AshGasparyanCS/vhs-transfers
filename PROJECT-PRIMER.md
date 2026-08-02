# VHS transfer business, context primer

Drop this in a new Claude chat on any machine to catch it up. Style note, same as
the homelab primer: no em dashes ever, commas or hyphens instead, keep it casual.

Last updated: 2026-08-02

## What this is

A small side business converting people's VHS and VHS-C tapes to digital files,
run out of Los Angeles. One person operation. Free pickup and return at the
customer's door, which is the main selling point since mail-in competitors
physically cannot offer it.

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
| `index.html` | The whole site. Single self-contained page, no JS, no external requests |
| `intake-form.html` | Printable tape intake and receipt form, print to PDF with Ctrl+P |
| `README.md` | Deploy and update instructions |
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

**Add-ons:** customer's own USB drive free, 128GB drive supplied $25, DVD $8 per disc.

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

- Buying 128GB drives in a **5 pack for $65**, so **$13 each**. Charging $25, so
  about $12 margin.
- 128GB is the right single stock size. Digitized video runs about **1.4GB per
  hour**, so 128GB holds roughly 90 hours, which covers a 25 tape collection
  comfortably. One SKU means never having to think about whether an order fits.
- An earlier $95 for 5 listing was rejected as overpriced at $19 each.

**Counterfeit drives are the real risk here.** Fake flash drives report a large
capacity to the OS but physically hold far less, write "successfully", then
silently corrupt. For this business that means handing someone the only copy of a
dead relative's wedding and having it be garbage six months later. Buy SanDisk,
Samsung, PNY or Kingston from Amazon's own listing, not third party sellers, and
verify every drive on arrival:

```bash
sudo apt install -y f3
lsblk                        # find the device, e.g. sdb
f3probe --time-ops /dev/sdb  # detects fake capacity specifically
```

Once per drive when the pack arrives, not per customer.

## Workflow and the intake form

`intake-form.html` prints to a 2 page form. Page 1 is the main intake, 12 tape
rows plus terms and signatures. Page 2 is a continuation sheet for orders past
12 tapes, only print when needed.

**Print two copies of page 1**, one for the customer and one for the business,
and both parties sign both. There is a second signature block at the bottom for
when the tapes are returned and payment is taken.

Writing down every tape together at pickup costs nothing, reassures people a lot,
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

Open decision: buy a second VCR and capture setup before advertising hard, or
soften that turnaround promise on the site. Do not let this go unresolved before
a marketing push.

## Open tasks

1. **Verify the flash drives with `f3probe`** when the 5 pack arrives. A script
   to loop every plugged-in drive and print pass/fail was offered but not written yet.
2. **Resolve the capacity question** above, second VCR or softer promise.
3. **Marketing.** Nextdoor is likely the single best channel given the free pickup
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
- Free pickup and return is the lead selling point, ahead of price.
- Google Voice number rather than personal cell, because the site is public.
- Commercial and copyrighted tapes are declined, this is standard industry
  practice and it is on both the site FAQ and the intake form.
- 128GB as the single drive size.
- Repo named `vhs-transfers` rather than taking the `ashgasparyancs.github.io`
  bare URL slot, which is being kept free for something personal.

# VHS to Digital, one page site

Single self-contained `index.html`. No build step, no dependencies, no JavaScript.
Drop it on GitHub Pages and it works.

## Already published

The site is live at https://ashgasparyancs.github.io/vhs-transfers/ with real
contact details filled in. Nothing needs replacing.

If any of these change, they each appear in more than one place, so grep the
whole directory rather than editing one file:

| Detail | Current | Where |
| --- | --- | --- |
| Phone | (818) 732-8094 | `index.html` display text AND the `tel:+18187328094` link |
| Email | ashgasparyan04+vhs@gmail.com | `index.html` and `intake-form.html` |
| Area | Los Angeles & surrounding | `index.html` contact card, title, meta tags |
| Prices | see `PROJECT-PRIMER.md` | `index.html` and `intake-form.html` both |

Consider setting a business name in the `<title>` if one is ever chosen.

## Publish it on GitHub Pages, free

Repo name: **`vhs-transfers`**, public (Pages requires public on the free tier).
Live URL will be `https://<username>.github.io/vhs-transfers`.

`gh` is installed at `~/.local/bin/gh` and this directory is already a git repo
with both files staged. One interactive step is needed first:

```bash
gh auth login
```

GitHub.com → HTTPS → yes to authenticating git → web browser.

Then:

```bash
cd ~/vhs-site

# Use the GitHub noreply alias so your real email never lands in public
# commit history. Find yours at github.com/settings/emails
git config user.name  "<username>"
git config user.email "<username>@users.noreply.github.com"

git commit -m "VHS conversion site"
gh repo create vhs-transfers --public --source=. --push
gh api -X POST repos/{owner}/vhs-transfers/pages -f 'source[branch]=main' -f 'source[path]=/'
```

The last line switches Pages on without visiting the web UI. Give it a minute,
then `gh browse --settings` shows the live URL.

### Updating it later

Edit `index.html`, then:

```bash
cd ~/vhs-site && git add -A && git commit -m "update pricing" && git push
```

Live site refreshes within about a minute. You can also edit straight in the
GitHub web editor if you're away from this machine.

## Preview it locally first

```bash
cd ~/vhs-site && python3 -m http.server 8099
```

Then open `http://192.168.4.35:8099` from any machine on the LAN.

Port 8099 was picked to stay clear of the media stack. Note that 8080, 8090, 8282
and 5000 are already taken by qbit, PufferPanel, Vaultwarden and server-status.

## A custom domain, if you want one later

GitHub Pages supports custom domains for free. You already run Cloudflare DNS for
`173842069.xyz`, so you could point a subdomain at it. That said, for a business
you'd probably want a real name rather than a number domain, and those run about
$10-15 a year.

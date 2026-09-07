# Quick Reference Card

## Essential Commands

```bash
# Go to blog directory
cd $HOME/Codes/blog

# Start local server
npx hexo s

# Create new post
npx hexo new post "Title"

# Generate & Deploy
npx hexo clean && npx hexo g -d
```

## Key Files Location

| What | Where |
|------|-------|
| Hexo Config | `_config.yml` |
| NexT Config | `_config.next.yml` |
| New Posts | `source/_posts/` |
| Drafts | `source/_drafts/` |
| Images | `source/images/` |
| Avatar | `source/images/avatar.jpg` |
| Generated Site | `public/` |

## Common Config Changes

### Change Sidebar Position
Edit `_config.next.yml`:
```yaml
sidebar:
  position: right  # or left
```

### Change Avatar
1. Replace `source/images/avatar.jpg`
2. Edit `_config.next.yml`:
```yaml
avatar:
  url: /images/avatar.jpg
  rounded: true    # circular shape
  rotated: false   # rotate on hover
```

### Change Scheme
Edit `_config.next.yml`:
```yaml
scheme: Mist   # Muse, Mist, Pisces, Gemini
```

### Add Menu Item
Edit `_config.next.yml`:
```yaml
menu:
  Home: / || home
  NewItem: /newitem/ || icon-name
```

## Font Awesome 5 Icons (NexT v8)

Use **simple names**, no `fa fa-` prefix:
- `home`, `user`, `tags`, `archive`, `image`
- `github`, `envelope`, `linkedin`, `link`
- `gift`, `heartbeat`, `calendar`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Changes not showing | `npx hexo clean` then regenerate |
| Sidebar on wrong side | Clear browser cache (Ctrl+F5) |
| Icons not showing | Use simple icon names, check console |
| Deploy failed | Check SSH key: `ssh -T git@github.com` |

---
*Keep this handy!*

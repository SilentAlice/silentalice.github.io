# Blog Management Guide - Memory Document

## Project Overview
- **Blog**: `$HOME/Codes/blog` (Hexo 8.1.1, NexT v8.27.0)

---

## Migration Summary (2025-03-21)

### What Was Done
1. ✅ Migrated Hexo from v7.3.0 to v8.1.1
2. ✅ Migrated NexT theme from v7 (git) to v8.27.0 (npm)
3. ✅ Migrated 88 blog posts from `source/_posts/`
4. ✅ Migrated 5 drafts from `source/_drafts/`
5. ✅ Migrated all images (242 files)
6. ✅ Migrated custom scaffolds (post, page, draft templates)
7. ✅ Migrated custom favicon and avatar images

### Key Configuration Files

| File | Purpose |
|------|---------|
| `$HOME/Codes/blog/_config.yml` | Main Hexo configuration |
| `$HOME/Codes/blog/_config.next.yml` | NexT theme configuration (alternate theme config) |
| `$HOME/Codes/blog/package.json` | NPM dependencies |

---

## Directory Structure

```
$HOME/Codes/blog/
├── _config.yml              # Main Hexo config
├── _config.next.yml         # NexT theme config (custom settings)
├── package.json             # NPM dependencies
├── package-lock.json
├── db.json                  # Generated (can be deleted)
├── scaffolds/               # Post templates
│   ├── draft.md
│   ├── page.md
│   └── post.md
├── source/                  # Content directory
│   ├── _drafts/            # Draft posts
│   ├── _posts/             # Published posts (88 posts)
│   ├── about/              # About page
│   ├── tags/               # Tags page
│   ├── images/             # Images & assets
│   │   ├── avatar.jpg      # Custom avatar (55KB)
│   │   ├── favicon-16x16-next.png
│   │   ├── favicon-32x32-next.png
│   │   ├── apple-touch-icon-next.png
│   │   ├── alipay.jpg      # Payment QR codes
│   │   ├── wechatpay.jpg
│   │   └── ... (other images)
│   ├── CNAME               # Domain config (silentming.net)
│   └── baidu_verify_*.html # Baidu verification
├── public/                  # Generated static site (deploy to GitHub)
├── node_modules/            # NPM packages (don't commit)
└── themes/                  # Empty (theme installed via npm)
```

---

## Key Configurations

### 1. Hexo Config (`_config.yml`)

```yaml
# Site
title: SilentMing's Gensokyo
subtitle: 初心忘れるべからず
description: SilentMing / SilentAlice's blog
author: SilentMing
language: en
timezone: Asia/Shanghai

# URL
url: http://silentming.net
root: /
permalink: blog/:year/:month/:day/:title/

# Theme
theme: next

# Deployment
deploy:
  type: git
  repo: git@github.com:SilentAlice/silentalice.github.io.git
  branch: master

# RSS Feed
plugin:
- hexo-generator-feed
feed:
  type: atom
  path: atom.xml
  limit: 20
```

### 2. NexT Theme Config (`_config.next.yml`)

**Important Settings:**
```yaml
# Scheme (currently using Mist)
scheme: Mist

# Dark Mode
darkmode: true

# Sidebar (RIGHT position)
sidebar:
  position: right      # Changed from left to right
  display: always
  padding: 18
  offset: 12
  onmobile: false

# Avatar (sidebar icon)
avatar:
  url: /images/avatar.jpg
  rounded: false       # Set to true for circular
  rotated: false       # Set to true for hover rotation

# Menu Icons (Font Awesome 5 format)
menu:
  Home: http://silentalice.github.io/WebGL/ || gift
  Blog: / || home
  About: about/ || user
  Tags: tags/ || tags
  Archives: archives/ || archive
  Gallery: http://silentalice.github.io/gallery/ || image

# Social Links
social:
  GitHub: https://github.com/SilentAlice || github
  Mail: mailto:yumingwu233@gmail.com || envelope
  LinkedIn: https://www.linkedin.com/in/silentalice/ || linkedin
  Pixiv: https://pixiv.me/wym981230 || link

# Comments (Disqus)
disqus:
  enable: true
  shortname: "silentmingsblog"
  count: true

# Analytics
baidu_analytics: 2830251be0f3ab7be6bbd750f9133e29

# Local Search
local_search:
  enable: true
  trigger: auto
  top_n_per_article: 1
```

---

## Common Commands

### Development
```bash
cd $HOME/Codes/blog

# Start local server (http://localhost:4000)
npx hexo server

# Or shorthand
npx hexo s

# Generate static files
npx hexo generate
npx hexo g

# Clean generated files
npx hexo clean

# Clean + Generate
npx hexo clean && npx hexo generate

# Deploy to GitHub
npx hexo deploy
npx hexo d

# Generate + Deploy
npx hexo generate --deploy
npx hexo g -d
```

### Create Content
```bash
# Create new post
npx hexo new post "My New Post Title"

# Create new page
npx hexo new page "About"

# Create new draft
npx hexo new draft "Draft Title"

# Publish draft to post
npx hexo publish draft "Draft Title"
```

### NPM Management
```bash
# Install dependencies
npm install

# Update packages
npm update

# Check outdated packages
npm outdated

# Install new plugin
npm install hexo-plugin-name
```

---

## Important Notes & Warnings

### 1. Image Assets
- **Custom images** are stored in `source/images/`
- **Avatar**: `source/images/avatar.jpg` (copied from old blog)
- **Favicons**: `favicon-16x16-next.png`, `favicon-32x32-next.png`
- **Apple Touch Icon**: `apple-touch-icon-next.png`

**To update avatar:**
1. Replace `source/images/avatar.jpg`
2. Config in `_config.next.yml` under `avatar:` section
3. Regenerate: `npx hexo clean && npx hexo generate`

### 2. NexT v8 vs v7 Differences
- Theme installed via **npm** (not git clone)
- Config is in `_config.next.yml` (not `themes/next/_config.yml`)
- Font Awesome 5 icons use simplified format (`home` not `fa fa-home`)
- Icons for brands: `github`, `linkedin` (no need for `fab` prefix in config)
- Menu icons: Use simple names like `home`, `user`, `tags`

### 3. Font Awesome 5 Icon Reference
Common icons used:
- `home` - Home
- `user` - About/User
- `tags` - Tags
- `archive` - Archives
- `image` - Gallery
- `gift` - Special/Home link
- `github` - GitHub
- `envelope` - Email
- `linkedin` - LinkedIn
- `link` - Generic link

### 4. Sidebar Position
- Currently set to `right` in `_config.next.yml`
- If it appears on left, clear browser cache (Ctrl+F5)
- Mist scheme shows sidebar on the side

### 5. Deployment
- Deploys to: `git@github.com:SilentAlice/silentalice.github.io.git`
- Branch: `master`
- Requires SSH key setup for GitHub

### 6. Scheme Options
Available schemes in NexT:
- `Muse` - Default black-white tone
- `Mist` - Tighter version (CURRENTLY USING)
- `Pisces` - Double-column, fresh look
- `Gemini` - Like Pisces with column shadows

Change in `_config.next.yml`:
```yaml
#scheme: Muse
scheme: Mist
#scheme: Pisces
#scheme: Gemini
```

---

## Troubleshooting

### Sidebar still on left after setting to right
1. Clear browser cache: `Ctrl+Shift+Delete` → Clear cache
2. Hard refresh: `Ctrl+F5`
3. Test in incognito window
4. Check `npx hexo clean && npx hexo generate`

### Icons not showing
1. Make sure using Font Awesome 5 format (simple names, not `fa fa-`)
2. Brand icons: use simple name like `github` not `fab fa-github`
3. Check browser console for 404 errors

### Theme changes not applying
1. Run `npx hexo clean` to clear cache
2. Regenerate `npx hexo generate`
3. Check `_config.next.yml` is in blog root directory

### Deploy failing
1. Check SSH key: `ssh -T git@github.com`
2. Verify repo access
3. Check `_config.yml` deploy settings

---

## Installed Plugins

```json
{
  "hexo": "^8.0.0",
  "hexo-deployer-git": "^4.0.0",
  "hexo-generator-archive": "^2.0.0",
  "hexo-generator-category": "^2.0.0",
  "hexo-generator-feed": "^4.0.0",
  "hexo-generator-index": "^4.0.0",
  "hexo-generator-searchdb": "^1.5.0",
  "hexo-generator-tag": "^2.0.0",
  "hexo-renderer-ejs": "^2.0.0",
  "hexo-renderer-marked": "^7.0.0",
  "hexo-renderer-stylus": "^3.0.1",
  "hexo-server": "^3.0.0",
  "hexo-theme-landscape": "^1.0.0",
  "hexo-theme-next": "^8.27.0"
}
```

---

## Future Tasks Reminder

When helping manage this blog in the future, remember:

1. **Always work in**: `$HOME/Codes/blog`
2. **Test locally** before deploying: `npx hexo server`
3. **Clean before major changes**: `npx hexo clean`
4. **Backup custom images** before any risky operations
5. **Theme config** is `_config.next.yml` (not in themes/ folder)
6. **Hexo config** is `_config.yml`
7. **Custom scaffolds** are in `scaffolds/` folder

---

## Contact & Resources

- **Hexo Docs**: https://hexo.io/docs/
- **NexT Docs**: https://theme-next.js.org/
- **Font Awesome Icons**: https://fontawesome.com/icons
- **GitHub Repo**: SilentAlice/silentalice.github.io

---

*Generated: 2025-03-21*
*Hexo Version: 8.1.1*
*NexT Version: 8.27.0*

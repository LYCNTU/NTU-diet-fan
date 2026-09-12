# Deploy DIET 飯 to Vercel

This folder is a standard Next.js project for Vercel.

## Vercel Drop
1. Upload the whole project folder (not the old Work/Cloudflare build).
2. Framework Preset: Next.js.
3. Install Command: leave default (`npm install`).
4. Build Command: leave default (`npm run build`).
5. Output Directory: leave blank/default.
6. Deploy.

No environment variables are required for this demo. Data is stored in browser localStorage.

## Why this V2 exists
The ChatGPT Work export contained Vinext/Cloudflare files such as `vite.config.ts` that import `.openai/hosting.json`. Those files are not part of a normal Vercel Next.js deployment and were removed here.

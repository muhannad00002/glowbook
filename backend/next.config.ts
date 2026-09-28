import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // API-only app: no pages, no images. Keep the server bundle lean.
  poweredByHeader: false,
  serverExternalPackages: ["pg", "@prisma/adapter-pg"],
};

export default nextConfig;

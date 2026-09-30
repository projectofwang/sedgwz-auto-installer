import { defineConfig, triggers } from "cf/config";

/**
 * This migration needs manual work. Resolve every TODO in this file, then remove the error below.
 */
/**
 * TODO(@cloudflare): cf migrate: An ancestor package.json was found, but it was not modified because it may belong to another project. Install `cf@latest` as a dev dependency in the package that owns this Worker.
 */
throw new Error("Migration incomplete. Resolve every cf migrate TODO in `cloudflare.config.ts`.");

export default defineConfig({
	worker: {
		name: "doh-dns-download",
		compatibilityDate: "2026-09-27",
		triggers: [
			triggers.fetch({
				pattern: "dl.taiyuanwangjie.dpdns.org/*",
				zone: "taiyuanwangjie.dpdns.org",
			}),
		],
	},
});

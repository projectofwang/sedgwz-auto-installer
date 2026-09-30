import { defineConfig, triggers } from "cf/config";

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

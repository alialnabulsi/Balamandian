# Marketplace image assets

Exact photographs from the user-approved interactive design reference:

- `images/coffee.jpg`: https://balamandian-v0-2-0.vercel.app/assets/coffee.jpg
- `images/food.jpg`: https://balamandian-v0-2-0.vercel.app/assets/food.jpg
- `images/books.jpg`: https://balamandian-v0-2-0.vercel.app/assets/books.jpg

Downloaded unchanged. `images/generic.svg` is a locally authored neutral storefront
fallback. These are imagery only; place names, IDs, categories and other content
always come from the API. The development-slug-to-photo mapping is centralized in
`lib/ui/marketplace/widgets/marketplace_tokens.dart`.

All files are declared by the marketplace image directory in `pubspec.yaml`.
Network images take priority and fall back through `MarketplaceImage`. Neither
provided screenshots nor temporary design URLs are runtime assets. See
`Docs/marketplace.md` for design-source and rendering verification details.

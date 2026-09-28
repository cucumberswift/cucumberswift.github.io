# cucumberswift.github.io

The GitHub Pages site for [CucumberSwift](https://github.com/cucumberswift/CucumberSwift): the project website at https://cucumberswift.org/.

## How it works

- `site/` holds the website. It is edited elsewhere and published to this repository, so changes made to it here are overwritten.
- The [Deploy](.github/workflows/deploy.yml) workflow deploys `site/` to GitHub Pages when `site/` changes on `main`, or when it is run by hand.
- The documentation is not deployed from here. Each package publishes its own to its own Pages site, which GitHub serves under this domain: [/CucumberSwift/](https://cucumberswift.org/CucumberSwift/) and [/CucumberSwiftExpressions/](https://cucumberswift.org/CucumberSwiftExpressions/).
- This site served the documentation before, under `/help/` and `/docs/`. The deploy adds a redirect page for each of those pages, to the same page on the package's site ([scripts/add-redirects.sh](scripts/add-redirects.sh), [CucumberSwift#176](https://github.com/cucumberswift/CucumberSwift/issues/176)). The pages are listed in `redirects/`. The lists are fixed and never need updating.

## Reserved paths

The website must not use these paths, because they belong to the documentation and to redirects from old documentation URLs. The deploy fails if `site/` contains any of them.

`/help/`, `/docs/`, `/CucumberSwift/`, `/CucumberSwiftExpressions/`, `/documentation/`, `/tutorials/`, `/sitemap.xml`, `/robots.txt`

## Issues

Report problems with the website or the documentation in [CucumberSwift](https://github.com/cucumberswift/CucumberSwift/issues).

## License

[MIT](LICENSE)

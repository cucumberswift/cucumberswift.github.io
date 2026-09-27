# cucumberswift.github.io

The GitHub Pages site for [CucumberSwift](https://github.com/cucumberswift/CucumberSwift): the project website and, once they are added, its documentation.

## How it works

- `site/` holds the website. It is edited elsewhere and published to this repository, so changes made to it here are overwritten.
- The [Deploy](.github/workflows/deploy.yml) workflow deploys `site/` to GitHub Pages when `site/` changes on `main`, or when it is run by hand.
- The documentation for CucumberSwift and CucumberSwiftExpressions is added during the deploy ([CucumberSwift#152](https://github.com/cucumberswift/CucumberSwift/issues/152)). It is not stored in this repository.

## Reserved paths

The website must not use these paths, because they belong to the documentation and to redirects from old documentation URLs. The deploy fails if `site/` contains any of them.

`/docs/`, `/CucumberSwift/`, `/CucumberSwiftExpressions/`, `/documentation/`, `/tutorials/`, `/sitemap.xml`, `/robots.txt`

## Issues

Report problems with the website or the documentation in [CucumberSwift](https://github.com/cucumberswift/CucumberSwift/issues).

## License

[MIT](LICENSE)

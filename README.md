# cppcheck-bughunting-action

## Installation

Add the following code in your repo root `.github/workflows/bug-hunting.yml`:

```yaml
name: Bug Hunting

on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]

jobs:
  bug-hunting:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          ref: "${{ github.head_ref }}"
          fetch-depth: 2

      - uses: jubnzv/cppcheck-bughunting-action@master
        env:
          GITHUB_TOKEN: "${{ secrets.GITHUB_TOKEN }}"
```

Create a pull request with some C or C++ code and you should see any warnings as annotations.

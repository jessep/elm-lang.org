# Elm Home Page

All of [elm-lang.org](http://elm-lang.org) is written in Elm. This repo
contains all that source code, both for the frontend and for the backend.

You can also use this to run [elm-lang.org/try](http://elm-lang.org/try)
locally.

## Set up

1. Get the Elm developer workflow setup by reading the [build from source instructions][bfs-readme] 
2. Run [this script][bfs] with `runhaskell BuildFromSource.hs master`. Be aware that this is all the actively developed branches, so things may be in an intermediate state.

[bfs-readme]: https://github.com/elm-lang/elm-platform/blob/master/README.md
[bfs]: https://github.com/elm-lang/elm-platform/blob/master/installers/BuildFromSource.hs

3. In the `Elm-Platform/master/` directory, run these commands:

```bash
git clone https://github.com/elm-lang/elm-lang.org.git
cd elm-lang.org
git checkout master
cabal sandbox init --sandbox ../.cabal-sandbox
cabal install --only-dependencies
cabal configure
cabal build
./dist/build/run-elm-website/run-elm-website
```

Great! You should be set up with [elm-lang.org](http://elm-lang.org/) running at
[localhost:8000/](http://localhost:8000/).

You can run `cabal clean` to clear out all cached build information and start fresh.

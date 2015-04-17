import Graphics.Element exposing (..)
import Markdown
import Website.Skeleton exposing (skeleton)
import Website.Tiles as Tile
import Window

port title : String
port title = "Elm 0.15"


main =
  Signal.map (skeleton "Blog" everything) Window.dimensions


everything wid =
  let w = min 600 wid
  in
    flow down
      [ width w content
      ]

content = Markdown.toElement """

# Tasks

Tasks make it easy to describe asynchronous operations that may fail, like
HTTP requests or writing to a database. Tons of browser APIs are described as
tasks in Elm:

  * [elm-http][] &mdash; talk to servers
  * [elm-history][] &mdash; navigate browser history
  * [elm-storage][] &mdash; save info in the users browser

[elm-http]: http://package.elm-lang.org/packages/evancz/elm-http/latest/
[elm-history]: https://github.com/TheSeamau5/elm-history/
[elm-storage]: https://github.com/TheSeamau5/elm-storage/

Tasks also work like light-weight threads in Elm, so you can have a bunch of
tasks running at the same time and the [runtime][rts] will hop between them if
they are blocked.

[rts]: http://en.wikipedia.org/wiki/Runtime_system

This tutorial is going to slowly build up to some realistic examples of HTTP
requests. The first few sections are explaining the building blocks, so stick
with it until we start putting it all together!


## Basic Example

Let’s start out with a very simple function for printing values out to the
console:

```haskell
print : a -> Task x ()
```

We give the `print` function a value, and it gives back a `Task` that can
be performed at some point and will print that value out. The `x` is a
placeholder that normally says what kind of errors can happen, but try not to
get hung up on it too much at this point. We will come back to it! The
important thing is that we have a task for printing stuff out.

To actually make the task happen, we give it to a [port][], which looks like
this.

[port]: /learn/Ports.elm

```haskell
module Counter where

import Time exposing (second)


-- A signal that updates to the current time every second
clock : Signal Time
clock =
  Time.every second


-- Turn the clock into a signal of tasks
printTasks : Signal (Task x ())
printTasks =
  Signal.map print clock


-- Actually perform all those tasks
port runner : Signal (Task x ())
port runner =
  printTasks
```

When we initialize the `Counter` module we will see the current time printed
out every second. The `printTasks` signal is creating a bunch of tasks, but
that does not do anything on its own. Just like in real life, creating a task
does not mean the task magically happens. I can write &ldquo;buy more
milk&rdquo; on my todo list as many times as I want, but I still need to go to
the grocery store and buy it if I want the milk to appear in my refrigerator.

So in Elm, tasks are not run until we hand them to the runtime through a port.
This is similar to sending a record or list out a port, but instead of handing
it to some JavaScript callback, the runtime just performs the task.


## Chaining Tasks

In the example above we used `print` but what if we want to create a more
complex task? Something with many steps. It is possible to chain many tasks
together with the `andThen` function. In the following example, to get the
current time *and then* print it out.

```haskell
-- task that succeeds with the current time
getCurrentTime : Task x Time


port runner : Task x ()
port runner =
  getCurrentTime `andThen` print
```

This means we try to get the current time *and then* when that succeeds we
print the time out. The key to chaining tasks together like this is the
`andThen` function.

```haskell
andThen : Task x a -> (a -> Task x b) -> Task x b
```

The first argument is a task that we want to happen, in our example this is
`getCurrentTime`. The second argument is a callback that creates a brand new
task. In our case this means taking the current time and printing it.

It may be helpful to see the slightly more verbose version of our task chain:

```haskell
printTime : Task x ()
printTime =
  getCurrentTime `andThen` print


printTimeVerbose : Task x ()
printTimeVerbose =
  getCurrentTime `andThen` \\time -> print time
```

These are both exactly the same, but in the second one, it is a bit more
explicit that we are waiting for a `time` and then printing it out.


## Communicating with Mailboxes

So far we have just been performing tasks and throwing away the result. But
what if we are getting some information from a server and need to bring that
back into our program? We can use a [`Mailbox`][mb], just like when
[constructing UIs][arch] that need to talk back!

[mb]: http://package.elm-lang.org/packages/elm-lang/core/latest/Signal#Mailbox
[arch]: https://github.com/evancz/elm-architecture-tutorial/

```haskell
type alias Mailbox a =
    { address : Address a
    , signal : Signal a
    }

mailbox : a -> Mailbox a
```

A mailbox has two key parts: (1) an address that you can send messages to and
(2) a signal that updates whenever a message is received. You create a mailbox
by providing an initial value for the `Signal`.

For our purposes here, the [`send`][send] function is one major way to send
messages to a mailbox.

[send]: http://package.elm-lang.org/packages/elm-lang/core/latest/Signal#send

```haskell
send : Address a -> a -> Task x ()
```

You provide an address and a value, and when the task is performed, that value
shows up at the corresponding mailbox. It&rsquo;s kinda like real mailboxes!
Let’s do a small example that uses `Mailbox` and `send`.

```haskell
main : Signal Element
main =
  Signal.map show contentMailbox.signal


contentMailbox : Signal.Mailbox String
contentMailbox =
  Signal.mailbox ""


port updateContent : Task x ()
port updateContent =
  Signal.send contentMailbox.address "hello!"
```

This program starts out showing an empty string, the initial value in the
mailbox. We immediately start running the `updateContent` task which sends a
new message to `contentMailbox`. When it arrives, the value of
`contentMailbox.signal` updates and we start showing `"hello!"` on screen.

Now that we have a feel for `andThen` and for `Mailbox` let’s try a more
useful example!


## HTTP Tasks

One of the most common thing you will want to do in a web app is talk to
servers. The [elm-http][] library provides everything you need for that, so
let&rsquo;s try to get a feel for how it works with the `Http.getString`
function.

```haskell
Http.getString : String -> Task Http.Error String
```

We provide a URL, and it will create a task that that tries to fetch the
resource that lives at that location as a `String`. Looking at the type of the
`Task`, finally that darn `x` is filled in with a real error type! This task
will either fail with some [`Http.Error`][error] or succeed with a `String`.

This exact function is actually used to load the README for packages in the
[Elm Package Catalog][epc]. Let’s look at the code far that!

[error]: http://package.elm-lang.org/packages/evancz/elm-http/latest/Http#Error
[epc]: http://package.elm-lang.org/

```haskell
import Http
import Markdown


main : Signal Html
main =
  Signal.map Markdown.toHtml readme.signal


-- set up mailbox
--   the signal is piped directly to main
--   the address lets us update the signal
readme : Signal.Mailbox String
readme =
  Signal.mailbox ""


-- send some markdown to our readme mailbox
report : String -> Task x ()
report markdown =
  Signal.send readme.address markdown


-- get the readme *and then* send the result to our mailbox
port fetchReadme : Task Http.Error ()
port fetchReadme =
  Http.getString readmeUrl `andThen` report


-- the URL of the README.md that we desire
readmeUrl : String
readmeUrl =
  "http://package.elm-lang.org/packages/elm-lang/core/latest/README.md"
```

The most interesting part is happening in the `fetchReadme` port. We attempt to
get the resource at `readmeUrl`. If we succeed, we `report` it to the `readme`
mailbox. If we fail, the whole chain of tasks fails and no message is sent.

So assuming the Elm Package Catalog responds, we will see a blank screen turn
into the contents of the elm-lang/core readme!


## More to come...

  * How to read lots of `andThen` chained together. Trick: when you start an
    anonymous function, it captures everything afterwards.

  * Talk about error handling with `onError`

  * Talk about functions like `Task.sequence`

Maybe show this example? Maybe it can help explain how badly we are not
following typical indentation rules to make it look nicer?

```haskell
getDuration : Task x Time
getDuration =
  getCurrentTime
    `andThen` \\start -> succeed (fibonacci 20)
    `andThen` \\fib -> getCurrentTime
    `andThen` \\end -> succeed (end - start)
```
"""
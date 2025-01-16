#lang scribble/manual

@title{Upgrading from earlier 6.x and 7.x versions of Racket}

@section{Linux}

@itemlist[
  @item{Download the newer release from @url{https://download.racket-lang.org/}.}
  @item{@code{chmod +x racket-X.Y-PLATFORM.sh}}
  @item{@code{./racket-X.Y-PLATFORM.sh} and answer the questions to choose where the new version should be installed.}
  @item{@code{raco pkg migrate}
  @item{@code{raco setup}}]

Note that in order to preserve the DrRacket preferences, it is currently necessary to manually copy the old Racket configuration folder to the new one (these folders can be @code{~/.racket/RACKET_VERSION} or @code{~/.racket/snapshot} for a nightly build).

@section{Upgrading from earlier versions}

If I'm not mistaken, @code{raco} was introduced at some point durign the 5.x series?
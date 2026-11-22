## 1.2.1

* First release on pub.dev.
* onSharedText also delivers a selection sent with Android ACTION_PROCESS_TEXT (the host app declares the
  PROCESS_TEXT text/plain intent-filter, e.g. a "save the selection as a note" action).

## 1.2.0

* takeSharedFile + ShareFileReceiverActivity: an image or PDF shared to the app (Android ACTION_SEND image/* and
  application/pdf, ACTION_SEND_MULTIPLE image/*), copied to the cache (a PDF as its first page rendered to a PNG) and
  handed over once.

## 1.1.0

* onSharedText: text shared to the app (Android ACTION_SEND text/*), the launch share and every later one.

## 1.0.0

* getLastDeepLink, onDeepLink, launchApp, isAppInstalled.

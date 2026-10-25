# Migration: mosaic order (`GrowingUpDisplayOrder` model)

## What changed

- New Core Data model version `GrowingUpDisplayOrder.xcdatamodel`, now the current
  version of `GrowingUp.xcdatamodeld`. It is a copy of `GrowingUpCelebrations` with one
  new attribute on `CoreDataPerson`:
  `displayOrder` — non-optional `Integer 64`, scalar, default `0`.
- `Person` carries `displayOrder`, and its `Comparable` order is
  (`displayOrder`, `createdDate`). The mosaic, the viewer's pages, the Home Screen and
  Lock Screen widgets and the widgets' `personIndex` links all sort with it, so they
  share one order.
- `CoreDataPersonsGateway.fetchPersons` sorts by `displayOrder`, then `createdDate`.
  `add` gives a new person the highest stored `displayOrder` plus one, so they join the
  end. `reorder(_:)` writes 1…n in the given order and puts anyone missing from the list
  after them; an unknown person fails the whole reorder without saving.

## Why lightweight migration is enough

Adding a non-optional attribute with a default value is an inferable change, so no
mapping model is needed. Every existing person gets `displayOrder = 0`, and since ties
fall back to `createdDate`, the mosaic keeps today's creation order without a data
migration. The first reorder writes 1…n to everyone; until then, a new person gets 1
and sorts after everyone at 0.

## How to verify

- Unit tests: `CoreDataPersonsGatewayTests` migrates a store created with
  `GrowingUpCelebrations` to the current model, checks that people, pins and photos
  survive, that people inserted out of creation order come back in creation order, and
  that the next person joins the end. `CoreDataPersonsOrderTests` covers add, reorder,
  removal, edits and an unknown person.
- Upgraded install: install the previous TestFlight build with several people, then
  install this build over it. The mosaic and widgets keep the creation order. Long-press
  a tile, drag it elsewhere, tap Done, relaunch: the new order persists in the mosaic,
  the viewer's swipes and the widgets.

class_name InventoryPublication
extends RefCounted
## Pure preflight, infallible main-thread apply, then post-commit notification.
## Used for new world containers and crafting queue changes in the same commit.
var validate: Callable
var apply: Callable
var notify: Callable

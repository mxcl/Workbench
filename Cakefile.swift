import Cakefile

dependencies = [
    .cake(~>1.0),
    .github("mxcl/PromiseKit" ~> 6.7),
    .github("Weebly/OrderedSet" ~> 3),
    .github("mxcl/LegibleError" ~> 1),
    .github("mxcl/Path.swift" ~> 0.13),
    .github("PromiseKit/CloudKit" ~> 3.1),
    .github("mxcl/AppUpdater" ~> 1.0)
]

platforms = [.macOS ~> 10.14]

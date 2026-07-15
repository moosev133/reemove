# Keep only rules required by the final dependency graph.
# Do not add broad -keep class ** { *; } rules because they disable meaningful shrinking.
-keepattributes *Annotation*
-keepattributes Signature

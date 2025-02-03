
#=============================================
#  export plantuml diagram from a collection
#=============================================

# All requires
################

( \
echo -e '@startuml\n'; \
(yq r -j ../packages/apps/collection.yaml \
| jq -r '{buildbase: "<< (B,#6495ED) >>", layerbase: "<< (λ,#98FB98) >>", layers: "<< (L,#9ACD32) >>", libs: "<< (l,#FF7700) >>", apps: "<< (a,#FF00FF) >>", utils: "<< (u,#4B0082) >>", fonts: "<< (f,#48D1CC) >>", development: "<< (d,#D4AC0D) >>", entity: "<< (e,#5DADE2) >>"} as $packages_styles
       | {buildbase: "<color:#6495ED><U+2756></color>", layerbase: "<color:#98FB98><U+2756></color>", layers: "<color:#9ACD32><U+2756></color>", libs: "<color:#FF7700><U+1F79B></color>", apps: "<color:#FF00FF><U+25C9></color>", utils: "<color:#4B0082><U+2318></color>", fonts: "<color:#48D1CC><U+24D5></color>", development: "<color:#D4AC0D><U+24D3></color>", entity: "<color:#5DADE2><U+24D4></color>", system: "<color:#DC7633><U+24E2></color>", provides: "<color:#34495E><U+24DF></color>"} as $deps_styles
       | .packages[]
       | [(if (.optrequires) then .requires[] + .optrequires[] else .requires[] end)] as $deps
       | "entity \"\(.name)\" as \(.category)/\(.name) \($packages_styles[.category]) {\n\( ( (if (.provides) then [( .provides[] | "  \($deps_styles["provides"]) \(.category)-\(.name)" )] | join("\n") | . + "\n..\n" else "" end) ) )\( ( [ $deps[] | "  \($deps_styles[.category]) \(.category)-\(.name)" ] ) | join("\n") )\n}"'); \
echo -e '\n'; \
(yq r -j ../packages/apps/collection.yaml \
| jq -r '.packages[]
       | .name as $name
       | .category as $category
       | if (.optrequires) then .requires[] + .optrequires[] else .requires[] end
       | "\"" + $category + "/" + $name + "\" --u--> \"\(.category)/\(.name)\""'); \
echo -e '\n@enduml'; \
) > apps-collection.puml

# All requires from C-R:
##########################

( \
echo -e '@startuml\n'; \
(yq r -j ../packages/apps/collection.yaml \
| jq -r '{buildbase: "<< (B,#6495ED) >>", layerbase: "<< (λ,#98FB98) >>", layers: "<< (L,#9ACD32) >>", libs: "<< (l,#FF7700) >>", apps: "<< (a,#FF00FF) >>", utils: "<< (u,#4B0082) >>", fonts: "<< (f,#48D1CC) >>", development: "<< (d,#D4AC0D) >>", entity: "<< (e,#5DADE2) >>"} as $packages_styles
       | {buildbase: "<color:#6495ED><U+2756></color>", layerbase: "<color:#98FB98><U+2756></color>", layers: "<color:#9ACD32><U+2756></color>", libs: "<color:#FF7700><U+1F79B></color>", apps: "<color:#FF00FF><U+25C9></color>", utils: "<color:#4B0082><U+2318></color>", fonts: "<color:#48D1CC><U+24D5></color>", development: "<color:#D4AC0D><U+24D3></color>", entity: "<color:#5DADE2><U+24D4></color>", system: "<color:#DC7633><U+24E2></color>", provides: "<color:#34495E><U+24DF></color>"} as $deps_styles
       | .packages[]
       | [(if (.optrequires) then .requires[] + .optrequires[] else .requires[] end)] as $deps
       | "entity \"\(.name)\" as \(.category)/\(.name) \($packages_styles[.category]) {\n\( ( (if (.provides) then [( .provides[] | "  \($deps_styles["provides"]) \(.category)-\(.name)" )] | join("\n") | . + "\n..\n" else "" end) ) )\( ( [ $deps[] | "  \($deps_styles[.category]) \(.category)-\(.name)" ] ) | join("\n") )\n}"'); \
echo -e '\n'; \
(yq r -j ../packages/apps/collection.yaml \
| jq -r '(.packages[] | "\(.category)/\(.name)") as $crpackages
       | .packages[]
       | .name as $name
       | .category as $category
       | if (.optrequires) then .requires[] + .optrequires[] else .requires[] end
       | select("\(.category)/\(.name)" | IN($crpackages)) | "\"" + $category + "/" + $name + "\" --u--> \"\(.category)/\(.name)\""'); \
echo -e '\n@enduml'; \
) > apps-collection-only.puml

# Run plantuml
################

PLANTUML_LIMIT_SIZE=65536 plantuml -tpdf .
PLANTUML_LIMIT_SIZE=65536 plantuml -tpng .
PLANTUML_LIMIT_SIZE=65536 plantuml -tsvg .

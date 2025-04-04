module Page.Problem exposing
    ( missingModule
    , notFound
    , offline
    , styles
    )

import Elm.Version as V
import Href
import Html exposing (Html)
import Html.Attributes as Attr



-- NOT FOUND


notFound : List (Html msg)
notFound =
    [ Html.div [ Attr.style "font-size" "12em" ] [ Html.text "404" ]
    , Html.div [ Attr.style "font-size" "3em" ] [ Html.text "I cannot find this page!" ]
    ]


styles : List (Html.Attribute msg)
styles =
    [ Attr.style "text-align" "center"
    , Attr.style "color" "#9A9A9A"
    , Attr.style "padding" "6em 0"
    ]



-- OFFLINE


offline : String -> List (Html msg)
offline file =
    [ Html.div [ Attr.style "font-size" "3em" ]
        [ Html.text "Cannot find "
        , Html.code [] [ Html.text file ]
        ]
    , Html.p [] [ Html.text "Are you offline or something?" ]
    ]



-- MISSING MODULE


missingModule : String -> String -> Maybe V.Version -> String -> List (Html msg)
missingModule author project version _ =
    [ Html.div [ Attr.style "font-size" "3em" ]
        [ Html.text "Module not found"
        ]
    , Html.p []
        [ Html.text "Maybe it existed in a "
        , Html.a [ Attr.href (Href.toProject author project) ] [ Html.text "previous release" ]
        , Html.text "?"
        , Html.br [] []
        , Html.text "Maybe the "
        , Html.a [ Attr.href (Href.toVersion author project version) ] [ Html.text "README" ]
        , Html.text " will help you figure out what changed?"
        ]
    ]

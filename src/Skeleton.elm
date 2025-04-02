module Skeleton exposing
    ( Details
    , Segment
    , Warning(..)
    , authorSegment
    , projectSegment
    , versionSegment
    , view
    )

import Browser
import Elm.Version as V
import Href
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Lazy exposing (..)
import Utils.Logo as Logo



-- NODE


type alias Details msg =
    { title : String
    , header : List Segment
    , warning : Warning
    , attrs : List (Attribute msg)
    , kids : List (Html msg)
    , year : Int
    }


type Warning
    = NoProblems
    | WarnOld
    | WarnMoved String String
    | WarnNewerVersion String V.Version



-- SEGMENT


type Segment
    = Text String
    | Link String String


authorSegment : String -> Segment
authorSegment author =
    Text author


projectSegment : String -> String -> Segment
projectSegment author project =
    Link (Href.toProject author project) project


versionSegment : String -> String -> Maybe V.Version -> Segment
versionSegment author project version =
    Link (Href.toVersion author project version) (vsnToString version)


vsnToString : Maybe V.Version -> String
vsnToString maybeVersion =
    case maybeVersion of
        Nothing ->
            "latest"

        Just version ->
            V.toString version



-- VIEW


view : (a -> msg) -> Details a -> Browser.Document msg
view toMsg details =
    { title =
        details.title
    , body =
        [ viewHeader details.header
        , lazy viewWarning details.warning
        , Html.map toMsg <|
            div (class "center" :: style "flex" "1" :: details.attrs) details.kids
        , viewFooter details.year
        ]
    }



-- VIEW HEADER


viewHeader : List Segment -> Html msg
viewHeader segments =
    div [ class "header" ]
        [ div [ class "nav" ]
            [ viewLogo
            , case segments of
                [] ->
                    text ""

                _ ->
                    h1 [] (List.intersperse slash (List.map viewSegment segments))
            ]
        ]


slash : Html msg
slash =
    span [ class "spacey-char" ] [ text "/" ]


viewSegment : Segment -> Html msg
viewSegment segment =
    case segment of
        Text string ->
            text string

        Link address string ->
            a [ href address ] [ text string ]



-- VIEW WARNING


viewWarning : Warning -> Html msg
viewWarning warning =
    div [ class "header-underbar" ] <|
        case warning of
            NoProblems ->
                []

            WarnOld ->
                [ p [ class "version-warning" ]
                    [ text "NOTE — this package is not compatible with Elm 0.19.1"
                    ]
                ]

            WarnMoved author project ->
                [ p [ class "version-warning" ]
                    [ text "NOTE — this package moved to "
                    , a [ href (Href.toVersion author project Nothing) ]
                        [ text (author ++ "/" ++ project)
                        ]
                    ]
                ]

            WarnNewerVersion url version ->
                [ p [ class "version-warning" ]
                    [ text "NOTE — the latest version is "
                    , a [ href url ] [ text (V.toString version) ]
                    ]
                ]



-- VIEW FOOTER


viewFooter : Int -> Html msg
viewFooter year =
    div [ class "footer" ]
        [ a [ class "grey-link", href "https://github.com/guida-lang/package-registry/" ] [ text "Site Source" ]
        , text (" — © " ++ String.fromInt year ++ " Décio Ferreira")
        ]



-- VIEW LOGO


viewLogo : Html msg
viewLogo =
    a
        [ href "/"
        , style "text-decoration" "none"
        , style "margin-right" "32px"
        , style "display" "flex"
        , style "align-items" "center"
        ]
        [ Logo.logo 40
        , div
            [ style "padding-left" "8px" ]
            [ div
                [ style "line-height" "24px"
                , style "font-size" "26px"
                ]
                [ text "guida" ]
            , div
                [ style "font-size" "16px"
                ]
                [ text "packages" ]
            ]
        ]

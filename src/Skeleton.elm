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
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Lazy
import Utils.Logo as Logo



-- NODE


type alias Details msg =
    { title : String
    , header : List Segment
    , warning : Warning
    , attrs : List (Html.Attribute msg)
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
        , Html.Lazy.lazy viewWarning details.warning
        , Html.map toMsg <|
            Html.div (Attr.class "center" :: Attr.style "flex" "1" :: details.attrs) details.kids
        , viewFooter details.year
        ]
    }



-- VIEW HEADER


viewHeader : List Segment -> Html msg
viewHeader segments =
    Html.div [ Attr.class "header" ]
        [ Html.div [ Attr.class "nav" ]
            [ viewLogo
            , case segments of
                [] ->
                    Html.text ""

                _ ->
                    Html.h1 [] (List.intersperse slash (List.map viewSegment segments))
            ]
        ]


slash : Html msg
slash =
    Html.span [ Attr.class "spacey-char" ] [ Html.text "/" ]


viewSegment : Segment -> Html msg
viewSegment segment =
    case segment of
        Text string ->
            Html.text string

        Link address string ->
            Html.a [ Attr.href address ] [ Html.text string ]



-- VIEW WARNING


viewWarning : Warning -> Html msg
viewWarning warning =
    Html.div [ Attr.class "header-underbar" ] <|
        case warning of
            NoProblems ->
                []

            WarnOld ->
                [ Html.p [ Attr.class "version-warning" ]
                    [ Html.text "NOTE — this package is not compatible with Elm 0.19.1"
                    ]
                ]

            WarnMoved author project ->
                [ Html.p [ Attr.class "version-warning" ]
                    [ Html.text "NOTE — this package moved to "
                    , Html.a [ Attr.href (Href.toVersion author project Nothing) ]
                        [ Html.text (author ++ "/" ++ project)
                        ]
                    ]
                ]

            WarnNewerVersion url version ->
                [ Html.p [ Attr.class "version-warning" ]
                    [ Html.text "NOTE — the latest version is "
                    , Html.a [ Attr.href url ] [ Html.text (V.toString version) ]
                    ]
                ]



-- VIEW FOOTER


viewFooter : Int -> Html msg
viewFooter year =
    Html.div [ Attr.class "footer" ]
        [ Html.a
            [ Attr.class "grey-link"
            , Attr.href "https://github.com/guida-lang/package-registry/"
            ]
            [ Html.text "Site Source"
            ]
        , Html.text (" — © " ++ String.fromInt year ++ " Décio Ferreira")
        ]



-- VIEW LOGO


viewLogo : Html msg
viewLogo =
    Html.a
        [ Attr.href "/"
        , Attr.style "text-decoration" "none"
        , Attr.style "margin-right" "32px"
        , Attr.style "display" "flex"
        , Attr.style "align-items" "center"
        ]
        [ Logo.logo 40
        , Html.div
            [ Attr.style "padding-left" "8px" ]
            [ Html.div
                [ Attr.style "line-height" "24px"
                , Attr.style "font-size" "26px"
                ]
                [ Html.text "guida" ]
            , Html.div
                [ Attr.style "font-size" "16px"
                ]
                [ Html.text "packages" ]
            ]
        ]

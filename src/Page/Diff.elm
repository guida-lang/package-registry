module Page.Diff exposing
    ( Model
    , Msg
    , Releases
    , init
    , update
    , view
    )

import Elm.Version as V
import Href
import Html exposing (Html)
import Html.Attributes as Attr
import Http
import Page.Problem as Problem
import Release
import Session
import Skeleton
import Utils.OneOrMore exposing (OneOrMore(..))



-- MODEL


type alias Model =
    { session : Session.Data
    , author : String
    , project : String
    , releases : Releases
    }


type Releases
    = Failure
    | Loading
    | Success (OneOrMore Release.Release)


init : Session.Data -> String -> String -> ( Model, Cmd Msg )
init session author project =
    case Session.getReleases session author project of
        Just releases ->
            ( Model session author project (Success releases)
            , Cmd.none
            )

        Nothing ->
            ( Model session author project Loading
            , Http.send GotReleases (Session.fetchReleases author project)
            )



-- UPDATE


type Msg
    = GotReleases (Result Http.Error (OneOrMore Release.Release))


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        GotReleases result ->
            case result of
                Err _ ->
                    ( { model | releases = Failure }
                    , Cmd.none
                    )

                Ok releases ->
                    ( { model
                        | releases = Success releases
                        , session = Session.addReleases model.author model.project releases model.session
                      }
                    , Cmd.none
                    )



-- VIEW


view : Model -> Skeleton.Details msg
view model =
    { title = model.author ++ "/" ++ model.project
    , header =
        [ Skeleton.authorSegment model.author
        , Skeleton.projectSegment model.author model.project
        ]
    , warning = Skeleton.NoProblems
    , attrs = [ Attr.class "pkg-overview" ]
    , kids =
        case model.releases of
            Failure ->
                [ Html.div Problem.styles (Problem.offline "releases.json")
                ]

            Loading ->
                [ Html.text "" -- TODO
                ]

            Success (OneOrMore r rs) ->
                [ Html.h1 [] [ Html.text "Published Versions" ]
                , Html.p [] <|
                    viewReleases model.author model.project <|
                        List.map .version (List.sortBy .time (r :: rs))
                ]
    , year = model.session.year
    }


viewReleases : String -> String -> List V.Version -> List (Html msg)
viewReleases author project versions =
    case versions of
        v1 :: ((v2 :: _) as vs) ->
            let
                attrs : List (Html.Attribute msg)
                attrs =
                    if isSameMajor v1 v2 then
                        []

                    else
                        [ bold ]
            in
            viewReadmeLink author project v1 attrs
                :: Html.text ", "
                :: viewReleases author project vs

        r0 :: [] ->
            [ viewReadmeLink author project r0 [ bold ] ]

        [] ->
            []


bold : Html.Attribute msg
bold =
    Attr.style "font-weight" "bold"


viewReadmeLink : String -> String -> V.Version -> List (Html.Attribute msg) -> Html msg
viewReadmeLink author project version attrs =
    let
        url : String
        url =
            Href.toVersion author project (Just version)
    in
    Html.a (Attr.href url :: attrs) [ Html.text (V.toString version) ]


isSameMajor : V.Version -> V.Version -> Bool
isSameMajor v1 v2 =
    let
        ( major1, _, _ ) =
            V.toTuple v1

        ( major2, _, _ ) =
            V.toTuple v2
    in
    major1 == major2

module Page.Help exposing
    ( Content
    , Model
    , Msg
    , init
    , update
    , view
    )

import Html exposing (Html)
import Html.Attributes as Attr
import Http
import Markdown
import Session
import Skeleton



-- MODEL


type alias Model =
    { session : Session.Data
    , title : String
    , content : Content
    }


type Content
    = Failure
    | Loading
    | Success String


init : Session.Data -> String -> String -> ( Model, Cmd Msg )
init session title url =
    ( Model session title Loading
    , Http.send GotContent (Http.getString url)
    )



-- UPDATE


type Msg
    = GotContent (Result Http.Error String)


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        GotContent result ->
            case result of
                Err _ ->
                    ( { model | content = Failure }, Cmd.none )

                Ok content ->
                    ( { model | content = Success content }, Cmd.none )



-- VIEW


view : Model -> Skeleton.Details msg
view model =
    { title = model.title
    , header = []
    , warning = Skeleton.NoProblems
    , attrs = []
    , kids = [ viewContent model.title model.content ]
    , year = model.session.year
    }


viewContent : String -> Content -> Html msg
viewContent title content =
    case content of
        Failure ->
            Html.text ""

        -- TODO
        Loading ->
            Html.h1 [ Attr.style "max-width" "600px" ] [ Html.text title ]

        Success help ->
            Markdown.toHtml [ Attr.style "max-width" "600px" ] help

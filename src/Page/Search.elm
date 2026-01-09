module Page.Search exposing
    ( Entries
    , Model
    , Msg
    , init
    , update
    , view
    )

import Elm.Version as V
import Href
import Html exposing (Html)
import Html.Attributes exposing (autofocus, class, href, placeholder, style, value)
import Html.Events as Events
import Html.Keyed as Keyed
import Html.Lazy
import Http
import Json.Decode as Decode
import Page.Problem as Problem
import Page.Search.Entry as Entry
import Session
import Skeleton



-- MODEL


type alias Model =
    { session : Session.Data
    , query : String
    , entries : Entries
    }


type Entries
    = Failure
    | Loading
    | Success (List Entry.Entry)


init : Session.Data -> ( Model, Cmd Msg )
init session =
    case Session.getEntries session of
        Just entries ->
            ( Model session "" (Success entries)
            , Cmd.none
            )

        Nothing ->
            ( Model session "" Loading
            , Http.send GotPackages <|
                Http.get "/search.json" (Decode.list Entry.decoder)
            )



-- UPDATE


type Msg
    = QueryChanged String
    | GotPackages (Result Http.Error (List Entry.Entry))


update : Msg -> Model -> ( Model, Cmd msg )
update msg model =
    case msg of
        QueryChanged query ->
            ( { model | query = query }
            , Cmd.none
            )

        GotPackages result ->
            case result of
                Err _ ->
                    ( { model | entries = Failure }
                    , Cmd.none
                    )

                Ok entries ->
                    ( { model
                        | entries = Success entries
                        , session = Session.addEntries entries model.session
                      }
                    , Cmd.none
                    )



-- VIEW


view : Model -> Skeleton.Details Msg
view model =
    { title = "Guida Packages"
    , header = []
    , warning = Skeleton.NoProblems
    , attrs = []
    , kids =
        [ Html.Lazy.lazy2 viewSearch model.query model.entries
        , viewSidebar
        ]
    , year = model.session.year
    }



-- VIEW SEARCH


viewSearch : String -> Entries -> Html Msg
viewSearch query entries =
    Html.div [ class "catalog" ]
        [ Html.input
            [ placeholder "Search"
            , value query
            , Events.onInput QueryChanged
            , autofocus True
            ]
            []
        , case entries of
            Failure ->
                Html.div Problem.styles (Problem.offline "search.json")

            Loading ->
                Html.text ""

            -- TODO
            Success es ->
                let
                    results : List ( String, Html msg )
                    results =
                        List.map viewEntry (Entry.search query es)
                in
                Html.div []
                    [ Keyed.node "div" [] <|
                        ( "h", viewHint (List.isEmpty results) query )
                            :: results
                    , Html.p [ class "pkg-hint" ]
                        [ Html.text "Need 0.18 packages? For "
                        , Html.a [ href "https://gist.github.com/evancz/9031e37902dfaec250a08a7aa6e17b10" ] [ Html.text "technical reasons" ]
                        , Html.text ", search "
                        , Html.a [ href "https://dmy.github.io/elm-0.18-packages/" ] [ Html.text "here" ]
                        , Html.text " instead!"
                        ]
                    ]
        ]



-- VIEW ENTRY


viewEntry : Entry.Entry -> ( String, Html msg )
viewEntry entry =
    ( entry.author ++ "/" ++ entry.project
    , Html.Lazy.lazy viewEntryHelp entry
    )


viewEntryHelp : Entry.Entry -> Html msg
viewEntryHelp ({ author, project, summary } as entry) =
    Html.div [ class "pkg-summary" ]
        [ Html.div []
            [ Html.h1 []
                [ Html.a [ href (Href.toVersion author project Nothing) ]
                    [ Html.span [ class "light" ] [ Html.text (author ++ "/") ]
                    , Html.text project
                    ]
                ]
            , viewExactVersions entry
            ]
        , Html.p [ class "pkg-summary-desc" ] [ Html.text summary ]
        ]


viewExactVersions : Entry.Entry -> Html msg
viewExactVersions entry =
    let
        latestUrl : String
        latestUrl =
            Href.toVersion entry.author entry.project (Just entry.version)

        latestName : String
        latestName =
            V.toString entry.version

        latestLink : Html msg
        latestLink =
            Html.a [ href latestUrl ] [ Html.text latestName ]
    in
    Html.span [ class "pkg-summary-hints" ] <|
        if V.toTuple entry.version == ( 1, 0, 0 ) then
            [ latestLink
            ]

        else
            [ Html.a [ href (Href.toProject entry.author entry.project) ] [ Html.text "…" ]
            , Html.text " "
            , latestLink
            ]



-- VIEW SIDEBAR


viewSidebar : Html msg
viewSidebar =
    Html.div [ class "catalog-sidebar" ]
        [ Html.h2 [] [ Html.text "Popular Packages" ]
        , Html.ul [] <|
            List.map viewPopularPackage [ "core", "html", "json", "browser", "url", "http" ]
        , Html.h2 [] [ Html.text "Resources" ]
        , Html.ul []
            [ Html.li [] [ Html.a [ href "https://klaftertief.github.io/elm-search/" ] [ Html.text "Search by Type" ] ]
            , Html.li [] [ Html.a [ href "https://github.com/elm-lang/elm-package/blob/master/README.md" ] [ Html.text "Using Packages" ] ]
            , Html.li [] [ Html.a [ href "/help/design-guidelines" ] [ Html.text "API Design Guidelines" ] ]
            , Html.li [] [ Html.a [ href "/help/documentation-format" ] [ Html.text "Write great docs" ] ]
            , Html.li [] [ Html.a [ href "https://guida-lang.org" ] [ Html.text "Guida Website" ] ]
            ]
        ]


viewPopularPackage : String -> Html msg
viewPopularPackage project =
    Html.li []
        [ Html.a
            [ href (Href.toVersion "elm" project Nothing)
            ]
            [ Html.span [ class "light" ] [ Html.text "elm/" ]
            , Html.text project
            ]
        ]



-- VIEW HINTS


viewHint : Bool -> String -> Html msg
viewHint noAlts query =
    viewHintHelp noAlts (String.toLower (String.replace "-" " " query)) hints


viewHintHelp : Bool -> String -> List (Hint msg) -> Html msg
viewHintHelp noAlts query remainingHints =
    case remainingHints of
        [] ->
            Html.text ""

        hint :: otherHints ->
            if String.startsWith query hint.term && (noAlts || String.length query >= hint.min) then
                hint.html

            else
                viewHintHelp noAlts query otherHints


type alias Hint msg =
    { term : String
    , min : Int
    , html : Html msg
    }


hints : List (Hint msg)
hints =
    [ Hint "spa" 3 singlePageApp
    , Hint "single page app" 5 singlePageApp
    , Hint "components" 5 components
    , Hint "router" 4 router
    , Hint "routing" 4 router
    , Hint "routes" 4 router
    , Hint "focus" 4 focus
    , Hint "blur" 4 focus
    , Hint "scroll" 4 scroll
    , Hint "scrollheight" 7 scroll
    , Hint "scrollwidth" 7 scroll
    , Hint "scrollx" 7 scroll
    , Hint "scrolly" 7 scroll
    , Hint "scrollto" 7 scroll
    , Hint "scrollintoview" 7 scroll
    , Hint "mouse" 4 mouse
    , Hint "keyboard" 4 keyboard
    , Hint "window" 4 window
    , Hint "visibility" 5 window
    , Hint "animation" 5 animation
    , Hint "requestanimationframe" 8 animation
    , Hint "lenses" 4 lenses
    ]


makeHint : List (Html msg) -> Html msg
makeHint message =
    Html.p [ class "pkg-hint" ] <|
        Html.b [] [ Html.text "Hint:" ]
            :: Html.text " "
            :: message


singlePageApp : Html msg
singlePageApp =
    makeHint
        [ Html.text "All single-page apps in Elm use "
        , codeLink (Href.toVersion "elm" "browser" Nothing) "elm/browser"
        , Html.text " to control the URL, with help from "
        , codeLink (Href.toVersion "elm" "url" Nothing) "elm/url"
        , Html.text " convert between URLs and nice structured data. I very highly recommend working through "
        , guide
        , Html.text " to learn how! Once you have made one or two single-page apps the standard way, it will be much easier to tell which (if any) of the packages below can make your code any easier."
        ]


components : Html msg
components =
    makeHint
        [ Html.text "Components are objects!"
        , Html.ul [ style "list-style-type" "none" ]
            [ Html.li [] [ Html.text "Components = Local State + Methods" ]
            , Html.li [] [ Html.text "Local State + Methods = Objects" ]
            ]
        , Html.text "We get very few folks asking how to structure Elm code with objects. Elm does not have objects! We get a lot of folks asking about how to use components, but it is essentially the same question. Elm emphasizes "
        , Html.i [] [ Html.text "functions" ]
        , Html.text " instead. Folks usually have the best experience if they follow the advice in "
        , guide
        , Html.text " and "
        , Html.a [ href "https://youtu.be/XpDsk374LDE" ] [ Html.text "The Life of a File" ]
        , Html.text ", exploring and understanding the techniques specific to Elm "
        , Html.i [] [ Html.text "before" ]
        , Html.text " trying to bring in techniques from other languages."
        ]


router : Html msg
router =
    makeHint
        [ Html.text "The "
        , codeLink (Href.toVersion "elm" "url" Nothing) "elm/url"
        , Html.text " package has everything you need to turn paths, queries, and hashes into useful data. But definitely work through "
        , guide
        , Html.text " to learn how this fits into a "
        , codeLink (Href.toModule "elm" "browser" Nothing "Browser" (Just "application")) "Browser.application"
        , Html.text " that manages the URL!"
        ]


focus : Html msg
focus =
    makeHint
        [ Html.text "Check out "
        , codeLink (Href.toModule "elm" "browser" Nothing "Browser.Dom" Nothing) "Browser.Dom"
        , Html.text " for focusing on certain nodes. It uses tasks, so be sure you have learned about "
        , Html.code [] [ Html.text "Cmd" ]
        , Html.text " values in "
        , guide
        , Html.text " and then read through the "
        , codeLink (Href.toModule "elm" "core" Nothing "Task" Nothing) "Task"
        , Html.text " module so you do not have to guess at how anything works!"
        ]


scroll : Html msg
scroll =
    makeHint
        [ Html.text "Check out "
        , codeLink (Href.toModule "elm" "browser" Nothing "Browser.Dom" Nothing) "Browser.Dom"
        , Html.text " for getting and setting scroll positions. It uses tasks, so be sure you have learned about "
        , Html.code [] [ Html.text "Cmd" ]
        , Html.text " values in "
        , guide
        , Html.text " and then read through the "
        , codeLink (Href.toModule "elm" "core" Nothing "Task" Nothing) "Task"
        , Html.text " module so you do not have to guess at how anything works!"
        ]


mouse : Html msg
mouse =
    makeHint
        [ Html.text "Folks usually use "
        , codeLink (Href.toModule "elm" "html" Nothing "Html.Events" Nothing) "Html.Events"
        , Html.text " to detect clicks on buttons. If you want mouse events for the whole page, you may want "
        , codeLink (Href.toModule "elm" "browser" Nothing "Browser.Events" Nothing) "Browser.Events"
        , Html.text " instead. Reading "
        , guide
        , Html.text " should give the foundation for using either!"
        ]


keyboard : Html msg
keyboard =
    makeHint
        [ Html.text "Folks usually use "
        , codeLink (Href.toModule "elm" "html" Nothing "Html.Events" Nothing) "Html.Events"
        , Html.text " for key presses in text fields. If you want keyboard events for the whole page, you may want "
        , codeLink (Href.toModule "elm" "browser" Nothing "Browser.Events" Nothing) "Browser.Events"
        , Html.text " instead. Reading "
        , guide
        , Html.text " should give the foundation for using either!"
        ]


window : Html msg
window =
    makeHint
        [ Html.text "Use "
        , codeLink (Href.toModule "elm" "browser" Nothing "Browser.Dom" Nothing) "Browser.Dom"
        , Html.text " to get the current window size, and use "
        , codeLink (Href.toModule "elm" "browser" Nothing "Browser.Events" Nothing) "Browser.Events"
        , Html.text " to detect when the window changes size or is not visible at the moment."
        ]


animation : Html msg
animation =
    makeHint
        [ Html.text "If you are not using CSS animations, you will need "
        , codeLink (Href.toModule "elm" "browser" Nothing "Browser.Events" (Just "onAnimationFrame")) "onAnimationFrame"
        , Html.text " to get smooth animations. The packages below may make one of these paths easier for you, but sometimes it is easier to just do things directly!"
        ]


lenses : Html msg
lenses =
    makeHint
        [ Html.text "Lenses are not commonly used in Elm. Their design focuses on manipulating deeply nested data structures, like records in records in dictionaries in lists. But rather than introducing a complex system to help with already complex data structures, we encourage folks to first work on simplifying the data structure."
        , Html.br [] []
        , Html.br [] []
        , Html.text "Maybe this means flattening records. Or using "
        , Html.a [ href "https://guide.elm-lang.org/types/custom_types.html" ] [ Html.text "custom types" ]
        , Html.text " to model different possibilities more precisely. Or representing graphs with "
        , codeText "Dict"
        , Html.text " values as described "
        , Html.a [ href "https://evancz.gitbooks.io/functional-programming-in-elm/graphs/" ] [ Html.text "here" ]
        , Html.text ". Or using the module system to create strong boundaries, using opaque types with helper functions to contain complexity."
        , Html.br [] []
        , Html.br [] []
        , Html.text "Point is, there are many paths to explore that will produce easier code with stronger guarantees, and folks are always happy to help if you share your situation on "
        , Html.a [ href "http://elmlang.herokuapp.com/" ] [ Html.text "Slack" ]
        , Html.text " or "
        , Html.a [ href "https://discourse.elm-lang.org/" ] [ Html.text "Discourse" ]
        , Html.text "!"
        ]


guide : Html msg
guide =
    codeLink "https://guide.elm-lang.org" "guide.elm-lang.org"


codeLink : String -> String -> Html msg
codeLink url txt =
    Html.a [ href url ] [ codeText txt ]


codeText : String -> Html msg
codeText txt =
    Html.code [] [ Html.text txt ]

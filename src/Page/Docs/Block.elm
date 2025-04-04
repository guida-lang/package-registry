module Page.Docs.Block exposing
    ( Info
    , TypeNameDict
    , makeInfo
    , view
    )

import Dict
import Elm.Docs as Docs
import Elm.Type as Type
import Elm.Version as V
import Href
import Html exposing (Html)
import Html.Attributes as Attr
import Utils.Markdown as Markdown



-- CONSTANTS


maxWidth : Int
maxWidth =
    64



-- VIEW


view : Info -> Docs.Block -> Html msg
view info block =
    case block of
        Docs.MarkdownBlock markdown ->
            Html.span [ Attr.class "markdown-block" ] [ Markdown.block markdown ]

        Docs.ValueBlock value ->
            viewValue info value

        Docs.BinopBlock binop ->
            viewBinop info binop

        Docs.AliasBlock alias ->
            viewAlias info alias

        Docs.UnionBlock union ->
            viewUnion info union

        Docs.UnknownBlock name ->
            Html.span
                [ Attr.class "TODO-make-this-red" ]
                [ Html.text "It seems that "
                , Html.code [] [ Html.text name ]
                , Html.text " does not have any docs. Please open a bug report "
                , Html.a [ Attr.href "https://github.com/elm/package.elm-lang.org/issues" ] [ Html.text "here" ]
                , Html.text " with the title “UnknownBlock found in docs” and with a link to this page in the description."
                ]


viewCodeBlock : String -> String -> List (Line msg) -> Html msg
viewCodeBlock name comment header =
    Html.div [ Attr.class "docs-block", Attr.id name ]
        [ Html.div [ Attr.class "docs-header" ] (List.map (Html.div []) header)
        , Html.div [ Attr.class "docs-comment" ] [ Markdown.block comment ]
        ]



-- VIEW VALUE BLOCK


viewValue : Info -> Docs.Value -> Html msg
viewValue info { name, comment, tipe } =
    let
        nameHtml : Html msg
        nameHtml =
            toBoldLink info name
    in
    viewCodeBlock name comment <|
        case toLines info Other tipe of
            One _ line ->
                [ nameHtml :: space :: colon :: space :: line ]

            More x xs ->
                [ nameHtml, space, colon ] :: indentFour x :: List.map indentFour xs


indentFour : Line msg -> Line msg
indentFour =
    (::) (Html.text "    ")



-- VIEW BINOP BLOCK


viewBinop : Info -> Docs.Binop -> Html msg
viewBinop info { name, comment, tipe } =
    let
        nameHtml : Html msg
        nameHtml =
            toBoldLink info ("(" ++ name ++ ")")
    in
    viewCodeBlock name comment <|
        case toLines info Other tipe of
            One _ line ->
                [ nameHtml :: space :: colon :: space :: line ]

            More x xs ->
                [ nameHtml, space, colon ] :: indentFour x :: List.map indentFour xs



-- VIEW ALIAS BLOCK


viewAlias : Info -> Docs.Alias -> Html msg
viewAlias info { name, args, comment, tipe } =
    let
        varsString : String
        varsString =
            String.concat (List.map (\a -> " " ++ a) args)

        aliasNameLine : List (Html msg)
        aliasNameLine =
            [ keyword "type"
            , space
            , keyword "alias"
            , space
            , toBoldLink info name
            , Html.text varsString
            , space
            , equals
            ]
    in
    viewCodeBlock name comment <|
        aliasNameLine
            :: List.map indentFour (linesToList (toLines info Other tipe))



-- VIEW UNION


viewUnion : Info -> Docs.Union -> Html msg
viewUnion info { name, comment, args, tags } =
    let
        varsString : String
        varsString =
            String.concat <| List.map (\a -> " " ++ a) args

        nameLine : List (Html msg)
        nameLine =
            [ keyword "type", space, toBoldLink info name, Html.text varsString ]
    in
    viewCodeBlock name comment <|
        case tags of
            [] ->
                [ nameLine ]

            t :: ts ->
                nameLine :: linesToList (toMoreLines (unionMore info) t ts)


unionMore : Info -> MoreSettings ( String, List Type.Type ) msg
unionMore info =
    let
        ctorToLines : ( String, List Type.Type ) -> OneOrMore (Line msg)
        ctorToLines ( ctor, args ) =
            toOneOrMore (toLines info Other (Type.Type ctor args))
    in
    { open = [ Html.text "    = " ]
    , sep = Html.text "    | "
    , close = Nothing
    , openIndent = 6
    , sepIndent = 6
    , toLines = ctorToLines
    }



-- INFO


type alias Info =
    { author : String
    , project : String
    , version : Maybe V.Version
    , moduleName : String
    , typeNameDict : TypeNameDict
    }


type alias TypeNameDict =
    Dict.Dict String ( String, String )


makeInfo : String -> String -> Maybe V.Version -> String -> List Docs.Module -> Info
makeInfo author project version moduleName docsList =
    let
        addUnion : String -> Docs.Union -> Dict.Dict String ( String, String ) -> Dict.Dict String ( String, String )
        addUnion home union docs =
            Dict.insert (home ++ "." ++ union.name) ( home, union.name ) docs

        addModule : Docs.Module -> Dict.Dict String ( String, String ) -> Dict.Dict String ( String, String )
        addModule docs dict =
            List.foldl (addUnion docs.name) dict docs.unions
    in
    Info author project version moduleName <|
        List.foldl addModule Dict.empty docsList



-- CREATE LINKS


toBoldLink : Info -> String -> Html msg
toBoldLink info name =
    makeLink info [ bold ] name name


bold : Html.Attribute msg
bold =
    Attr.style "font-weight" "bold"


makeLink : Info -> List (Html.Attribute msg) -> String -> String -> Html msg
makeLink { author, project, version, moduleName } attrs tagName humanName =
    let
        url : String
        url =
            Href.toModule author project version moduleName (Just tagName)
    in
    Html.a (Attr.href url :: attrs) [ Html.text humanName ]


toLinkLine : Info -> String -> Lines (Line msg)
toLinkLine info qualifiedName =
    case Dict.get qualifiedName info.typeNameDict of
        Nothing ->
            let
                shortName : String
                shortName =
                    last qualifiedName (String.split "." qualifiedName)
            in
            One (String.length shortName) [ Html.span [ Attr.title qualifiedName ] [ Html.text shortName ] ]

        Just ( moduleName, name ) ->
            One (String.length name) [ makeLink { info | moduleName = moduleName } [] name name ]


last : a -> List a -> a
last backup list =
    case list of
        [] ->
            backup

        x :: [] ->
            x

        _ :: xs ->
            last backup xs



-- LINES


type alias Line msg =
    List (Html msg)


type Lines line
    = One Int line
    | More line (List line)


type Context
    = Func
    | App
    | Other


toLines : Info -> Context -> Type.Type -> Lines (Line msg)
toLines info context tipe =
    case tipe of
        Type.Var x ->
            One (String.length x) [ Html.text x ]

        Type.Lambda arg result ->
            let
                lambdaToLine : Lines (Line msg) -> List (Lines (Line msg)) -> Lines (Line msg)
                lambdaToLine =
                    if context == Other then
                        toLinesHelp lambdaOne lambdaMore

                    else
                        toLinesHelp lambdaOneParens lambdaMoreParens
            in
            lambdaToLine (toLines info Func arg) <|
                List.map (toLines info Func) (collectArgs [] result)

        Type.Tuple [] ->
            One 2 [ Html.text "()" ]

        Type.Tuple (arg :: args) ->
            toLinesHelp tupleOne
                tupleMore
                (toLines info Other arg)
                (List.map (toLines info Other) args)

        Type.Type name args ->
            let
                needsParens : Bool
                needsParens =
                    context == App && not (List.isEmpty args)
            in
            toLinesHelp
                (typeOne needsParens)
                (typeMore needsParens)
                (toLinkLine info name)
                (List.map (toLines info App) args)

        Type.Record [] Nothing ->
            One 2 [ Html.text "{}" ]

        Type.Record [] (Just ext) ->
            One (6 + String.length ext) [ Html.text <| "{ " ++ ext ++ " | }" ]

        Type.Record (f :: fs) extension ->
            let
                toLns : ( String, Type.Type ) -> ( String, Lines (Line msg) )
                toLns ( field, fieldType ) =
                    ( field, toLines info Other fieldType )
            in
            case extension of
                Nothing ->
                    if List.isEmpty fs then
                        toLinesHelp recordOne recordMore (toLns f) (List.map toLns fs)

                    else
                        toMoreLines recordMore (toLns f) (List.map toLns fs)

                Just ext ->
                    case toLinesHelp (recordOneExt ext) recordMoreExt (toLns f) (List.map toLns fs) of
                        One width line ->
                            One width line

                        More first rest ->
                            More [ Html.text "{ ", Html.text ext ] (first :: rest ++ [ [ Html.text "}" ] ])



-- FUNCTIONS


collectArgs : List Type.Type -> Type.Type -> List Type.Type
collectArgs revArgs tipe =
    case tipe of
        Type.Lambda arg result ->
            collectArgs (arg :: revArgs) result

        _ ->
            List.reverse (tipe :: revArgs)


lambdaOne : OneSettings (Lines (Line msg)) msg
lambdaOne =
    { open = []
    , sep = [ Html.text " -> " ]
    , close = []
    , openWidth = 0
    , sepWidth = 2
    , closeWidth = 0
    , toLine = toLine
    }


lambdaMore : MoreSettings (Lines (Line msg)) msg
lambdaMore =
    { open = []
    , sep = Html.text "-> "
    , close = Nothing
    , openIndent = 0
    , sepIndent = 3
    , toLines = toOneOrMore
    }


lambdaOneParens : OneSettings (Lines (Line msg)) msg
lambdaOneParens =
    { open = [ Html.text "(" ]
    , sep = [ Html.text " -> " ]
    , close = [ Html.text ")" ]
    , openWidth = 1
    , sepWidth = 2
    , closeWidth = 1
    , toLine = toLine
    }


lambdaMoreParens : MoreSettings (Lines (Line msg)) msg
lambdaMoreParens =
    { open = [ Html.text "( " ]
    , sep = Html.text "  -> "
    , close = Just [ Html.text ")" ]
    , openIndent = 2
    , sepIndent = 5
    , toLines = toOneOrMore
    }



-- TUPLES


tupleOne : OneSettings (Lines (Line msg)) msg
tupleOne =
    { open = [ Html.text "( " ]
    , sep = [ Html.text ", " ]
    , close = [ Html.text " )" ]
    , openWidth = 2
    , sepWidth = 2
    , closeWidth = 2
    , toLine = toLine
    }


tupleMore : MoreSettings (Lines (Line msg)) msg
tupleMore =
    { open = [ Html.text "( " ]
    , sep = Html.text ", "
    , close = Just [ Html.text ")" ]
    , openIndent = 2
    , sepIndent = 2
    , toLines = toOneOrMore
    }



-- TYPES


typeOne : Bool -> OneSettings (Lines (Line msg)) msg
typeOne needsParens =
    if needsParens then
        { open = [ Html.text "(" ]
        , sep = [ Html.text " " ]
        , close = [ Html.text ")" ]
        , openWidth = 1
        , sepWidth = 1
        , closeWidth = 1
        , toLine = toLine
        }

    else
        { open = []
        , sep = [ Html.text " " ]
        , close = []
        , openWidth = 0
        , sepWidth = 1
        , closeWidth = 0
        , toLine = toLine
        }


typeMore : Bool -> MoreSettings (Lines (Line msg)) msg
typeMore needsParens =
    if needsParens then
        { open = [ Html.text "(" ]
        , sep = Html.text "    "
        , close = Just [ Html.text ")" ]
        , openIndent = 0
        , sepIndent = 4
        , toLines = toOneOrMore
        }

    else
        { open = []
        , sep = Html.text "    "
        , close = Nothing
        , openIndent = 0
        , sepIndent = 4
        , toLines = toOneOrMore
        }



-- RECORDS


recordOne : OneSettings ( String, Lines (Line msg) ) msg
recordOne =
    { open = [ Html.text "{ " ]
    , sep = [ Html.text ", " ]
    , close = [ Html.text " }" ]
    , openWidth = 2
    , sepWidth = 2
    , closeWidth = 2
    , toLine = fieldToLine
    }


recordMore : MoreSettings ( String, Lines (Line msg) ) msg
recordMore =
    { open = [ Html.text "{ " ]
    , sep = Html.text ", "
    , close = Just [ Html.text "}" ]
    , openIndent = 6
    , sepIndent = 6
    , toLines = fieldToLines
    }



-- EXTENDED RECORDS


recordOneExt : String -> OneSettings ( String, Lines (Line msg) ) msg
recordOneExt extension =
    let
        open : String
        open =
            "{ " ++ extension ++ " | "
    in
    { open = [ Html.text open ]
    , sep = [ Html.text ", " ]
    , close = [ Html.text " }" ]
    , openWidth = String.length open
    , sepWidth = 2
    , closeWidth = 2
    , toLine = fieldToLine
    }


recordMoreExt : MoreSettings ( String, Lines (Line msg) ) msg
recordMoreExt =
    { open = [ Html.text "    | " ]
    , sep = Html.text "    , "
    , close = Nothing
    , openIndent = 10
    , sepIndent = 10
    , toLines = fieldToLines
    }



-- RECORD HELPERS


fieldToLine : ( String, Lines (Line msg) ) -> Maybe ( Int, Line msg )
fieldToLine ( field, lines ) =
    case lines of
        More _ _ ->
            Nothing

        One width line ->
            Just ( String.length field + 3 + width, Html.text field :: space :: colon :: space :: line )


fieldToLines : ( String, Lines (Line msg) ) -> OneOrMore (Line msg)
fieldToLines ( field, lines ) =
    case lines of
        One width line ->
            let
                potentialWidth : Int
                potentialWidth =
                    String.length field + 3 + width
            in
            if potentialWidth < maxWidth then
                OneOrMore (Html.text field :: space :: colon :: space :: line) []

            else
                OneOrMore [ Html.text field, space, colon ] [ line ]

        More x xs ->
            OneOrMore [ Html.text field, space, colon ] (x :: xs)



-- HELPERS


toLine : Lines line -> Maybe ( Int, line )
toLine lines =
    case lines of
        One width line ->
            Just ( width, line )

        More _ _ ->
            Nothing


linesToList : Lines line -> List line
linesToList lines =
    case lines of
        One _ line ->
            [ line ]

        More x xs ->
            x :: xs


type OneOrMore a
    = OneOrMore a (List a)


toOneOrMore : Lines line -> OneOrMore line
toOneOrMore lines =
    case lines of
        One _ line ->
            OneOrMore line []

        More x xs ->
            OneOrMore x xs



-- TO LINES HELP


type alias OneSettings a msg =
    { open : Line msg
    , sep : Line msg
    , close : Line msg
    , openWidth : Int
    , sepWidth : Int
    , closeWidth : Int
    , toLine : a -> Maybe ( Int, Line msg )
    }


type alias MoreSettings a msg =
    { open : Line msg
    , sep : Html msg
    , close : Maybe (Line msg)
    , openIndent : Int
    , sepIndent : Int
    , toLines : a -> OneOrMore (Line msg)
    }


toLinesHelp : OneSettings a msg -> MoreSettings a msg -> a -> List a -> Lines (Line msg)
toLinesHelp one more x xs =
    case toOneLine one.openWidth one.open one (x :: xs) of
        Just ( width, line ) ->
            One width line

        Nothing ->
            toMoreLines more x xs


toOneLine : Int -> Line msg -> OneSettings a msg -> List a -> Maybe ( Int, Line msg )
toOneLine chunkWidth chunk one entries =
    case entries of
        [] ->
            Just ( one.closeWidth, one.close )

        entry :: remainingEntries ->
            one.toLine entry
                |> Maybe.andThen
                    (\( entryWidth, line ) ->
                        toOneLine one.sepWidth one.sep one remainingEntries
                            |> Maybe.andThen
                                (\( remainingWidth, remainingLine ) ->
                                    let
                                        width : Int
                                        width =
                                            chunkWidth + entryWidth + remainingWidth
                                    in
                                    if width < maxWidth then
                                        Just ( width, chunk ++ line ++ remainingLine )

                                    else
                                        Nothing
                                )
                    )


toMoreLines : MoreSettings a msg -> a -> List a -> Lines (Line msg)
toMoreLines s x xs =
    let
        (OneOrMore firstLine firstRest) =
            s.toLines x

        openIndentation : Html msg
        openIndentation =
            Html.text (String.repeat s.openIndent " ")

        sepIndentation : Html msg
        sepIndentation =
            Html.text (String.repeat s.sepIndent " ")

        toChunk : OneOrMore (List (Html msg)) -> List (List (Html msg))
        toChunk (OneOrMore y ys) =
            (s.sep :: y) :: List.map ((::) sepIndentation) ys

        otherLines : List (List (Html msg))
        otherLines =
            List.map ((::) openIndentation) firstRest
                ++ List.concatMap (toChunk << s.toLines) xs
    in
    More (s.open ++ firstLine) <|
        case s.close of
            Nothing ->
                otherLines

            Just closer ->
                otherLines ++ [ closer ]



-- HELPERS


keyword : String -> Html msg
keyword kw =
    Html.span [ Attr.class "hljs-keyword" ] [ Html.text kw ]


space : Html msg
space =
    Html.text " "


colon : Html msg
colon =
    Html.span [] [ Html.text ":" ]


equals : Html msg
equals =
    Html.span [] [ Html.text "=" ]

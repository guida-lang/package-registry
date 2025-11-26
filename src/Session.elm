module Session exposing
    ( Data
    , Outline(..)
    , addDocs
    , addEntries
    , addOutline
    , addReadme
    , addReleases
    , empty
    , fetchDocs
    , fetchOutline
    , fetchReadme
    , fetchReleases
    , getDocs
    , getEntries
    , getOutline
    , getReadme
    , getReleases
    )

import Dict
import Elm.Docs as Docs
import Elm.Project as ElmOutline
import Elm.Version as V
import Guida.Project as GuidaOutline
import Http
import Json.Decode as Decode
import Page.Search.Entry as Entry
import Release
import Url.Builder as Url
import Utils.OneOrMore exposing (OneOrMore)



-- SESSION DATA


type alias Data =
    { entries : Maybe (List Entry.Entry)
    , releases : Dict.Dict String (OneOrMore Release.Release)
    , readmes : Dict.Dict String String
    , docs : Dict.Dict String (List Docs.Module)
    , outlines : Dict.Dict String Outline
    , year : Int
    }


empty : Int -> Data
empty year =
    Data Nothing Dict.empty Dict.empty Dict.empty Dict.empty year



-- ENTRIES


getEntries : Data -> Maybe (List Entry.Entry)
getEntries data =
    data.entries


addEntries : List Entry.Entry -> Data -> Data
addEntries entries data =
    { data | entries = Just entries }



-- RELEASES


toPkgKey : String -> String -> String
toPkgKey author project =
    author ++ "/" ++ project


getReleases : Data -> String -> String -> Maybe (OneOrMore Release.Release)
getReleases data author project =
    Dict.get (toPkgKey author project) data.releases


addReleases : String -> String -> OneOrMore Release.Release -> Data -> Data
addReleases author project releases data =
    { data | releases = Dict.insert (toPkgKey author project) releases data.releases }


fetchReleases : String -> String -> Http.Request (OneOrMore Release.Release)
fetchReleases author project =
    Http.get
        (Url.absolute [ "packages", author, project, "releases.json" ] [])
        Release.decoder



-- README


toVsnKey : String -> String -> V.Version -> String
toVsnKey author project version =
    author ++ "/" ++ project ++ "@" ++ V.toString version


getReadme : Data -> String -> String -> V.Version -> Maybe String
getReadme data author project version =
    Dict.get (toVsnKey author project version) data.readmes


addReadme : String -> String -> V.Version -> String -> Data -> Data
addReadme author project version readme data =
    { data | readmes = Dict.insert (toVsnKey author project version) readme data.readmes }


fetchReadme : String -> String -> V.Version -> Http.Request String
fetchReadme author project version =
    Http.getString <|
        Url.absolute [ "packages", author, project, V.toString version, "README.md" ] []



-- DOCS


getDocs : Data -> String -> String -> V.Version -> Maybe (List Docs.Module)
getDocs data author project version =
    Dict.get (toVsnKey author project version) data.docs


addDocs : String -> String -> V.Version -> List Docs.Module -> Data -> Data
addDocs author project version docs data =
    { data | docs = Dict.insert (toVsnKey author project version) docs data.docs }


fetchDocs : String -> String -> V.Version -> Http.Request (List Docs.Module)
fetchDocs author project version =
    Http.get
        (Url.absolute [ "packages", author, project, V.toString version, "docs.json" ] [])
        (Decode.list Docs.decoder)



-- .JSON


type Outline
    = GuidaOutline GuidaOutline.PackageInfo
    | ElmOutline ElmOutline.PackageInfo


getOutline : Data -> String -> String -> V.Version -> Maybe Outline
getOutline data author project version =
    Dict.get (toVsnKey author project version) data.outlines


addOutline : String -> String -> V.Version -> Outline -> Data -> Data
addOutline author project version outline data =
    { data | outlines = Dict.insert (toVsnKey author project version) outline data.outlines }


fetchOutline : String -> String -> V.Version -> Http.Request Outline
fetchOutline author project version =
    Http.get
        (Url.absolute [ "packages", author, project, V.toString version, "json" ] [])
        outlineDecoder


outlineDecoder : Decode.Decoder Outline
outlineDecoder =
    Decode.oneOf
        [ guidaOutlineDecoder
            |> Decode.map GuidaOutline
        , elmOutlineDecoder
            |> Decode.map ElmOutline
        ]


guidaOutlineDecoder : Decode.Decoder GuidaOutline.PackageInfo
guidaOutlineDecoder =
    GuidaOutline.decoder
        |> Decode.andThen getGuidaPkgOutline


getGuidaPkgOutline : GuidaOutline.Project -> Decode.Decoder GuidaOutline.PackageInfo
getGuidaPkgOutline guidaOutline =
    case guidaOutline of
        GuidaOutline.Application _ ->
            Decode.fail "Unexpected application"

        GuidaOutline.Package info ->
            Decode.succeed info


elmOutlineDecoder : Decode.Decoder ElmOutline.PackageInfo
elmOutlineDecoder =
    ElmOutline.decoder
        |> Decode.andThen getElmPkgOutline


getElmPkgOutline : ElmOutline.Project -> Decode.Decoder ElmOutline.PackageInfo
getElmPkgOutline elmOutline =
    case elmOutline of
        ElmOutline.Application _ ->
            Decode.fail "Unexpected application"

        ElmOutline.Package info ->
            Decode.succeed info

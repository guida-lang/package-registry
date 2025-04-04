module Utils.Logo exposing (logo)

import Html
import Svg
import Svg.Attributes as SvgAttr



-- GUIDA LOGO


logo : Int -> Html.Html msg
logo n =
    Svg.svg
        [ SvgAttr.height (String.fromInt n)
        , SvgAttr.viewBox "0 0 52.917 52.917"
        ]
        [ Svg.path
            [ SvgAttr.fill "currentColor"
            , SvgAttr.d "M26.458 37.248c-52.644 0 24.646 37.221-8.178-3.938s-13.734 42.475-2.02-8.849-41.771 15.746 5.66-7.096-38.355-22.841 9.077 0-6.056-44.228 5.659 7.096 30.803-32.31-2.02 8.85c-32.823 41.158 44.466 3.937-8.178 3.937z"
            ]
            []
        ]

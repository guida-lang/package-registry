module Utils.OneOrMore exposing (OneOrMore(..))

-- ONE OR MORE


type OneOrMore a
    = OneOrMore a (List a)

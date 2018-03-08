module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)

main : Html msg
main =
    div [ class "games-index" ]
    [ ul [ class "games-list" ]
        [ li [] [ text "Platform Game" ]
        , li [] [ text "Adventure Game" ]
        ]
    ]


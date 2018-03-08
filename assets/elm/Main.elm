module Main exposing (..)

import Html exposing (..)

import Html.Attributes exposing (..)

main : Html msg
main =
    div []
    [ h1 [] [ text "Games" ]
    , gamesIndex
    ]

gamesIndex : Html msg
gamesIndex =
    div [ class "games-index" ] [ gamesList ]

gamesList : Html msg
gamesList =
    ul [ class "games-list" ] [ gamesListItem ]

gamesListItem : Html msg
gamesListItem =
    li [] [ text "Platform Game" ]

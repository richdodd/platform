module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Model =
    { gamesList : List Game
    , displayGamesList : Bool
    }


type alias Game =
    { gameTitle : String
    , gameDescription : String
    }


initialModel : Model
initialModel =
    { gamesList =
        [ { gameTitle = "Platform Game", gameDescription = "Platform game example." }
        , { gameTitle = "Adventure Game", gameDescription = "Adventure game example." }
        ]
    , displayGamesList = False
    }


init : ( Model, Cmd Msg )
init =
    ( initialModel, Cmd.none )



-- UPDATE


type Msg
    = DisplayGamesList
    | HideGamesList


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DisplayGamesList ->
            ( { model | displayGamesList = True }, Cmd.none )

        HideGamesList ->
            ( { model | displayGamesList = False }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ h1 [ class "games-section" ] [ text "Games" ]
        , button [ class "btn btn-success" ] [ text "Display Games List" ]
        , button [ class "btn btn-danger" ] [ text "Hide Games List" ]
        ]


gamesIndex : List String -> Html msg
gamesIndex gameTitles =
    div [ class "games-index" ] [ gamesList gameTitles ]


gamesList : List String -> Html msg
gamesList gameTitles =
    ul [ class "games-list" ] (List.map gamesListItem gameTitles)


gamesListItem : String -> Html msg
gamesListItem gameTitle =
    li [] [ text gameTitle ]

module Platformer exposing (..)

import AnimationFrame exposing (diffs)
import Html exposing (Html, button, div, li, span, strong, ul)
import Html.Attributes
import Html.Events exposing (onClick)
import Keyboard exposing (KeyCode, downs)
import Phoenix.Channel
import Phoenix.Push
import Phoenix.Socket
import Random
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Time exposing (Time, every, second)
import Json.Decode as Decode
import Json.Encode as Encode


-- MAIN


main : Program Flags Model Msg
main =
    Html.programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type Direction
    = Left
    | Right


type GameState
    = StartScreen
    | Playing
    | Success
    | GameOver


type alias Flags =
    { token : String
    }


type alias Gameplay =
    { gameId : Int
    , playerId : Int
    , playerScore : Int
    }


type alias Model =
    { characterDirection : Direction
    , characterPositionX : Int
    , characterPositionY : Int
    , gameplays : List Gameplay
    , gameState : GameState
    , itemPositionX : Int
    , itemPositionY : Int
    , itemsCollected : Int
    , phxSocket : Phoenix.Socket.Socket Msg
    , playerScore : Int
    , timeRemaining : Int
    }


initialModel : Flags -> Model
initialModel flags =
    { characterDirection = Right
    , characterPositionX = 50
    , characterPositionY = 300
    , gameplays = []
    , gameState = StartScreen
    , itemPositionX = 500
    , itemPositionY = 300
    , itemsCollected = 0
    , phxSocket = initialSocketJoin flags
    , playerScore = 0
    , timeRemaining = 10
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( initialModel flags, Cmd.map PhoenixMsg (initialSocketCommand flags) )


initialSocket : Flags -> ( Phoenix.Socket.Socket Msg, Cmd (Phoenix.Socket.Msg Msg) )
initialSocket flags =
    let
        devSocketServer =
            "ws://localhost:4000/socket/websocket?token=" ++ flags.token
    in
        Phoenix.Socket.init devSocketServer
            |> Phoenix.Socket.withDebug
            |> Phoenix.Socket.on "save_score" "score:platformer" SaveScore
            |> Phoenix.Socket.on "save_score" "score:platformer" ReceiveScoreChanges
            |> Phoenix.Socket.join initialChannel


initialChannel : Phoenix.Channel.Channel msg
initialChannel =
    Phoenix.Channel.init "score:platformer"


initialSocketJoin : Flags -> Phoenix.Socket.Socket Msg
initialSocketJoin flags =
    initialSocket flags
        |> Tuple.first


initialSocketCommand : Flags -> Cmd (Phoenix.Socket.Msg Msg)
initialSocketCommand flags =
    initialSocket flags
        |> Tuple.second



-- UPDATE


type Msg
    = NoOp
    | CountdownTimer Time
    | KeyDown KeyCode
    | PhoenixMsg (Phoenix.Socket.Msg Msg)
    | ReceiveScoreChanges Encode.Value
    | SaveScore Encode.Value
    | SaveScoreError Encode.Value
    | SaveScoreRequest
    | SetNewItemPositionX Int
    | TimeUpdate Time


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        KeyDown keyCode ->
            case keyCode of
                32 ->
                    if model.gameState /= Playing then
                        ( { model
                            | characterDirection = Right
                            , characterPositionX = 50
                            , itemsCollected = 0
                            , gameState = Playing
                            , playerScore = 0
                            , timeRemaining = 10
                          }
                        , Cmd.none
                        )
                    else
                        ( model, Cmd.none )

                37 ->
                    if model.gameState == Playing then
                        ( { model
                            | characterDirection = Left
                            , characterPositionX = model.characterPositionX - 15
                          }
                        , Cmd.none
                        )
                    else
                        ( model, Cmd.none )

                39 ->
                    if model.gameState == Playing then
                        ( { model
                            | characterDirection = Right
                            , characterPositionX = model.characterPositionX + 15
                          }
                        , Cmd.none
                        )
                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        PhoenixMsg msg ->
            let
                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.update msg model.phxSocket
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg phxCmd
                )

        SaveScoreRequest ->
            let
                payload =
                    Encode.object [ ( "player_score", Encode.int model.playerScore ) ]

                phxPush =
                    Phoenix.Push.init "save_score" "score:platformer"
                        |> Phoenix.Push.withPayload payload
                        |> Phoenix.Push.onOk SaveScore
                        |> Phoenix.Push.onError SaveScoreError

                ( phxSocket, phxCmd ) =
                    Phoenix.Socket.push phxPush model.phxSocket
            in
                ( { model | phxSocket = phxSocket }
                , Cmd.map PhoenixMsg phxCmd
                )

        SaveScore value ->
            ( model, Cmd.none )

        SaveScoreError message ->
            Debug.log "Error sending score over socket."
                ( model, Cmd.none )

        ReceiveScoreChanges raw ->
            case Decode.decodeValue gameplayDecoder raw of
                Ok scoreChange ->
                    ( { model | gameplays = scoreChange :: model.gameplays }, Cmd.none )

                Err message ->
                    Debug.log "Error receiving score changes."
                        ( model, Cmd.none )

        TimeUpdate time ->
            if characterFoundItem model then
                ( { model
                    | itemsCollected = model.itemsCollected + 1
                    , playerScore = model.playerScore + 100
                  }
                , Random.generate SetNewItemPositionX (Random.int 50 500)
                )
            else if model.itemsCollected >= 10 then
                ( { model | gameState = Success }, Cmd.none )
            else if model.itemsCollected < 10 && model.timeRemaining == 0 then
                ( { model | gameState = GameOver }, Cmd.none )
            else
                ( model, Cmd.none )

        CountdownTimer time ->
            if model.gameState == Playing && model.timeRemaining > 0 then
                ( { model | timeRemaining = model.timeRemaining - 1 }, Cmd.none )
            else
                ( model, Cmd.none )

        SetNewItemPositionX newPositionX ->
            ( { model | itemPositionX = newPositionX }, Cmd.none )


characterFoundItem : Model -> Bool
characterFoundItem model =
    let
        approximateItemLowerBound =
            model.itemPositionX - 35

        approximateItemUpperBound =
            model.itemPositionX

        approximateItemRange =
            List.range approximateItemLowerBound approximateItemUpperBound
    in
        List.member model.characterPositionX approximateItemRange



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ downs KeyDown
        , diffs TimeUpdate
        , every second CountdownTimer
        , Phoenix.Socket.listen model.phxSocket PhoenixMsg
        ]



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ viewGame model
        , viewSaveScoreButton
        , viewGameplaysIndex model
        ]


viewGame : Model -> Svg Msg
viewGame model =
    svg [ version "1.1", width "600", height "400" ]
        (viewGameState model)


viewItem : Model -> Svg Msg
viewItem model =
    image
        [ xlinkHref "/images/coin.svg"
        , x (toString model.itemPositionX)
        , y (toString model.itemPositionY)
        , width "20"
        , height "20"
        ]
        []


viewGameWindow : Svg Msg
viewGameWindow =
    rect
        [ width "600"
        , height "400"
        , fill "none"
        , stroke "black"
        ]
        []


viewGameSky : Svg Msg
viewGameSky =
    rect
        [ x "0"
        , y "0"
        , width "600"
        , height "300"
        , fill "#4b7cfb"
        ]
        []


viewGameGround : Svg Msg
viewGameGround =
    rect
        [ x "0"
        , y "300"
        , width "600"
        , height "100"
        , fill "green"
        ]
        []


viewCharacter : Model -> Svg Msg
viewCharacter model =
    let
        characterImage =
            case model.characterDirection of
                Left ->
                    "/images/character-left.gif"

                Right ->
                    "/images/character-right.gif"
    in
        image
            [ xlinkHref characterImage
            , x (toString model.characterPositionX)
            , y (toString model.characterPositionY)
            , width "50"
            , height "50"
            ]
            []


viewGameText : Int -> Int -> String -> Svg Msg
viewGameText positionX positionY str =
    Svg.text_
        [ x (toString positionX)
        , y (toString positionY)
        , fontFamily "Courier"
        , fontWeight "bold"
        , fontSize "16"
        ]
        [ Svg.text str ]


viewGameScore : Model -> Svg Msg
viewGameScore model =
    let
        currentScore =
            model.playerScore
                |> toString
                |> String.padLeft 5 '0'
    in
        Svg.svg []
            [ viewGameText 25 25 "SCORE"
            , viewGameText 25 40 currentScore
            ]


viewItemsCollected : Model -> Svg Msg
viewItemsCollected model =
    let
        currentItemCount =
            model.itemsCollected
                |> toString
                |> String.padLeft 3 '0'
    in
        Svg.svg []
            [ image
                [ xlinkHref "/images/coin.svg"
                , x "275"
                , y "18"
                , width "15"
                , height "15"
                ]
                []
            , viewGameText 300 30 ("x " ++ currentItemCount)
            ]


viewGameTime : Model -> Svg Msg
viewGameTime model =
    let
        currentTime =
            model.timeRemaining
                |> toString
                |> String.padLeft 4 '0'
    in
        Svg.svg []
            [ viewGameText 525 25 "TIME"
            , viewGameText 525 40 currentTime
            ]


viewGameState : Model -> List (Svg Msg)
viewGameState model =
    case model.gameState of
        StartScreen ->
            [ viewGameWindow
            , viewGameSky
            , viewGameGround
            , viewCharacter model
            , viewItem model
            , viewStartScreenText
            ]

        Playing ->
            [ viewGameWindow
            , viewGameSky
            , viewGameGround
            , viewCharacter model
            , viewItem model
            , viewGameScore model
            , viewItemsCollected model
            , viewGameTime model
            ]

        Success ->
            [ viewGameWindow
            , viewGameSky
            , viewGameGround
            , viewCharacter model
            , viewItem model
            , viewSuccessScreenText
            ]

        GameOver ->
            [ viewGameWindow
            , viewGameSky
            , viewGameGround
            , viewCharacter model
            , viewItem model
            , viewGameOverScreenText
            ]


viewStartScreenText : Svg Msg
viewStartScreenText =
    Svg.svg []
        [ viewGameText 140 160 "Collect ten coins in ten seconds!"
        , viewGameText 140 180 "Press the SPACE BAR key to start."
        ]


viewSuccessScreenText : Svg Msg
viewSuccessScreenText =
    Svg.svg []
        [ viewGameText 260 160 "Success!"
        , viewGameText 140 180 "Press the SPACE BAR key to restart."
        ]


viewGameOverScreenText : Svg Msg
viewGameOverScreenText =
    Svg.svg []
        [ viewGameText 260 160 "Game Over"
        , viewGameText 140 180 "Press the SPACE BAR key to restart."
        ]


viewSaveScoreButton : Html Msg
viewSaveScoreButton =
    div []
        [ button
            [ onClick SaveScoreRequest
            , class "btn btn-primary"
            ]
            [ text "Save Score" ]
        ]


viewGameplaysIndex : Model -> Html Msg
viewGameplaysIndex model =
    if List.isEmpty model.gameplays then
        div [] []
    else
        div [ Html.Attributes.class "players-index" ]
            [ viewGameplaysList model.gameplays
            ]


viewGameplaysList : List Gameplay -> Html Msg
viewGameplaysList gameplays =
    div [ Html.Attributes.class "players-list panel panel-info" ]
        [ div [ Html.Attributes.class "panel-heading" ] [ text "Player Scores" ]
        , ul [ Html.Attributes.class "list-group" ] (List.map viewGameplayItem gameplays)
        ]


viewGameplayItem : Gameplay -> Html Msg
viewGameplayItem gameplay =
    li [ Html.Attributes.class "player-item list-group-item" ]
        [ strong [] [ text (toString gameplay.playerId) ]
        , span [ Html.Attributes.class "badge" ] [ text (toString gameplay.playerScore) ]
        ]


gameplayDecoder : Decode.Decoder Gameplay
gameplayDecoder =
    Decode.map3 Gameplay
        (Decode.field "game_id" Decode.int)
        (Decode.field "player_id" Decode.int)
        (Decode.field "player_score" Decode.int)

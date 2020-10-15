port module Main exposing (main)

import Platform
import Json.Encode as Json
import Json.Decode as Decode

main =
  Platform.worker
    { init = init
    , update = update
    , subscriptions = subscriptions
    }

type alias Request =
  { method : String
  , headers : Json.Value
  , url : String
  , body : Maybe String
  }

type alias Response =
  { statusCode : Int
  , statusMessage : String
  , headers : Json.Value
  , body : String
  }



-- MODEL --

init : () -> ( (), Cmd Msg )
init _ =
  ( (), Cmd.none )



-- UPDATE --

type Msg
  = HttpRequest ( Json.Value, Id )
  | ReadResult ( Maybe String, Id )

update : Msg -> () -> ( (), Cmd Msg )
update msg model =
  case msg of
    HttpRequest ( reqJson, id ) ->
      case reqJson |> Decode.decodeValue requestDecoder of
        Ok req ->
          case ( req.method, req.url ) of
            ( "GET", url ) ->
              let
                path = url |> String.dropLeft 1
              in
                ( model, readFile ( path, id ) )

            _ ->
              ( model
              , response ( errorResponse 400 "Bad Request", id )
              )

        Err _ ->
          ( model
          , response ( errorResponse 400 "Bad Request", id )
          )

    ReadResult ( result, id ) ->
      case result of
        Nothing ->
          ( model
          , response ( errorResponse 404 "Not Found", id )
          )

        Just str ->
          ( model
          , response ( Response 200 "OK" mimeHtmlUtf8 str, id )
          )

requestDecoder : Decode.Decoder Request
requestDecoder =
  Decode.map4
  Request
  (Decode.field "method" Decode.string)
  (Decode.field "headers" Decode.value)
  (Decode.field "url" Decode.string)
  (Decode.field "body" Decode.string |> Decode.maybe)

errorResponse : Int -> String -> Response
errorResponse statusCode reason =
  Response statusCode reason
  mimeHtmlUtf8
  (String.fromInt statusCode++" "++reason++"." |> htmlH1)

htmlH1 : String -> String
htmlH1 str =
  "<html><head></head><body><h1>"++str++"</h1></body></html>"

mimeHtmlUtf8 : Json.Value
mimeHtmlUtf8 =
  ( "Content-Type", Json.string "text/html; charset=UTF-8" )
    |> List.singleton
    |> Json.object



-- SUBSCRIPTIONS --

subscriptions : () -> Sub Msg
subscriptions model =
  Sub.batch
  [ request HttpRequest
  , readResult ReadResult
  ]



-- PORTS --

type alias Id = Int

port request : (( Json.Value, Id ) -> msg) -> Sub msg
port response : ( Response, Id ) -> Cmd msg

port readFile : ( String, Id ) -> Cmd msg
port readResult : (( Maybe String, Id ) -> msg) -> Sub msg

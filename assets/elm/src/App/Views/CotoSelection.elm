module App.Views.CotoSelection exposing
    ( statusBar
    , update
    , view
    )

import App.I18n.Keys as I18nKeys
import App.Markdown
import App.Messages as AppMsg exposing (..)
import App.Submodels.Context exposing (Context)
import App.Submodels.LocalCotos exposing (LocalCotos)
import App.Submodels.NarrowViewport exposing (ActiveView(..), NarrowViewport)
import App.Submodels.WideViewport exposing (WideViewport)
import App.Types.Coto exposing (Coto, CotoId, CotoSelection, Cotonoma, ElementId)
import App.Views.Coto
import App.Views.CotoSelectionMsg as CotoSelectionMsg exposing (Msg(..))
import Exts.Maybe exposing (isJust)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Html.Keyed
import Process
import Set
import Task
import Time
import Utils.EventUtil exposing (onLinkButtonClick)
import Utils.HtmlUtil exposing (faIcon, materialIcon)
import Utils.StringUtil exposing (isBlank)
import Utils.UpdateUtil exposing (..)


type alias UpdateModel model =
    Context (WideViewport (NarrowViewport { model | selection : CotoSelection }))


update :
    Context context
    -> CotoSelectionMsg.Msg
    -> UpdateModel model
    -> ( UpdateModel model, Cmd AppMsg.Msg )
update context msg model =
    case msg of
        ColumnToggle ->
            model
                |> App.Submodels.WideViewport.toggleSelection
                |> withoutCmd

        DeselectingCoto cotoId ->
            model
                |> App.Submodels.Context.setBeingDeselected cotoId
                |> withCmd
                    (\model ->
                        Process.sleep (1 * Time.second)
                            |> Task.andThen (\_ -> Task.succeed ())
                            |> Task.perform (\_ -> AppMsg.CotoSelectionMsg DeselectCoto)
                    )

        DeselectCoto ->
            model
                |> App.Submodels.Context.finishBeingDeselected
                |> App.Submodels.WideViewport.closeSelectionIfEmpty context
                |> withoutCmd

        ClearSelection ->
            let
                activeView =
                    case model.narrowViewport.activeView of
                        SelectionView ->
                            FlowView

                        anotherView ->
                            anotherView
            in
            model
                |> App.Submodels.Context.clearSelection
                |> App.Submodels.WideViewport.closeSelection
                |> App.Submodels.NarrowViewport.switchActiveView activeView
                |> withoutCmd


type alias ViewModel model =
    LocalCotos (WideViewport { model | selection : CotoSelection })


statusBar : Context context -> ViewModel model -> Html AppMsg.Msg
statusBar context model =
    let
        count =
            model.selection |> List.length

        message =
            context.i18nText (I18nKeys.CotoSelection_CotosSelected count)
    in
    div
        [ id "coto-selection-bar"
        , classList
            [ ( "empty", List.isEmpty model.selection )
            ]
        ]
        [ a [ class "close", onClick (AppMsg.CotoSelectionMsg ClearSelection) ]
            [ faIcon "times" Nothing ]
        , div [ class "selection-info" ]
            [ faIcon "check-square-o" Nothing
            , span [ class "selection-count" ] [ text (toString count) ]
            , span [ class "text" ] [ text (" " ++ message) ]
            , a [ class "toggle", onClick (AppMsg.CotoSelectionMsg ColumnToggle) ]
                [ if model.wideViewport.selectionOpen then
                    faIcon "caret-up" Nothing

                  else
                    faIcon "caret-down" Nothing
                ]
            ]
        ]


view : Context context -> ViewModel model -> Html AppMsg.Msg
view context model =
    div [ id "coto-selection" ]
        [ div
            [ class "column-header" ]
            []
        , div
            [ class "column-body" ]
            [ selectedCotosDiv context model ]
        ]


titleMaxlength : Int
titleMaxlength =
    30


validateTitle : String -> Bool
validateTitle title =
    not (isBlank title) && String.length title <= titleMaxlength


selectedCotosDiv : Context context -> ViewModel model -> Html AppMsg.Msg
selectedCotosDiv context model =
    Html.Keyed.node
        "div"
        [ id "selected-cotos" ]
        (List.filterMap
            (\cotoId ->
                case App.Submodels.LocalCotos.getCoto cotoId model of
                    Nothing ->
                        Nothing

                    Just coto ->
                        Just
                            ( toString cotoId
                            , cotoDiv
                                context
                                (context.deselecting |> Set.member cotoId)
                                coto
                            )
            )
            (List.reverse model.selection)
        )


cotoDiv : Context a -> Bool -> Coto -> Html AppMsg.Msg
cotoDiv context beingDeselected coto =
    let
        elementId =
            "selection-" ++ coto.id
    in
    div
        [ classList
            [ ( "coto", True )
            , ( "animated", True )
            , ( "fadeOut", beingDeselected )
            ]
        ]
        [ div
            [ class "coto-inner" ]
            [ a
                [ class "tool-button deselect-coto"
                , title "Deselect coto"
                , onLinkButtonClick
                    (AppMsg.CotoSelectionMsg (DeselectingCoto coto.id))
                ]
                [ materialIcon
                    (if beingDeselected then
                        "check_box_outline_blank"

                     else
                        "check_box"
                    )
                    Nothing
                ]
            , App.Views.Coto.headerDiv context Nothing elementId coto
            , App.Views.Coto.bodyDiv context Nothing elementId App.Markdown.markdown coto
            , App.Views.Coto.openTraversalButtonDiv context.graph (isJust coto.asCotonoma) coto.id
            ]
        ]

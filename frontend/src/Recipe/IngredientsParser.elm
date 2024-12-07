module Recipe.IngredientsParser exposing (parseIngredients)

{-| The `IngredientsParser` module provides functionality for extracting
ingredients from a raw Markdown string. It parses the Markdown content,
identifies list items (both ordered and unordered), and returns them as
a list of strings.

This is particularly useful for scenarios where ingredients are stored
as Markdown but need to be processed programmatically for further use.


# Example Usage

    parseIngredients """
    ## Ingredienser
    - 1 kg mjöl
    - 1/2 dl vatten
    ## Tillbehör
    - tomat
    - gurka
    """
    --> [ "1 kg mjöl", "1/2 dl vatten", "tomat", "gurka" ]

-}

import Markdown.Block as Block exposing (Block(..), extractInlineText, mapAndAccumulate)
import Markdown.Parser exposing (parse)


{-| Parse a raw Markdown string to extract list items as a list of strings.
-}
parseIngredients : String -> List String
parseIngredients markdown =
    case parse markdown of
        Ok blocks ->
            mapAndAccumulate extractLists [] blocks
                |> Tuple.first

        Err _ ->
            []


{-| Extract list items from a single block, accumulating results in `soFar`.
We know valid ingredient markdown comprise only list items and headings, so that's all we look at.
There are other block types that can safely ignore (e.g. paragraphs, code blocks, etc).
-}
extractLists : List String -> Block -> ( List String, Block )
extractLists soFar block =
    let
        extractInlinesFromListItem item =
            case item of
                Block.ListItem _ inlines ->
                    extractInlineText inlines
    in
    case block of
        Block.UnorderedList items ->
            let
                listItems =
                    List.map extractInlinesFromListItem items
            in
            ( List.append soFar listItems, block )

        Block.OrderedList _ items ->
            let
                listItems =
                    List.map extractInlineText items
            in
            ( List.append soFar listItems, block )

        Block.Heading _ _ ->
            -- we ignore headings for now
            ( soFar, block )

        _ ->
            ( soFar, block )

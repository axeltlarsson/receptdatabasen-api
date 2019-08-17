module Page.Recipe.Editor.TagForm exposing (Tag, Values, blank, form)

import Form exposing (Form)


type alias Values =
    { tag : String }


type alias Tag =
    { tag : String }


blank : Values
blank =
    { tag = "" }


form : Int -> Form Values Tag
form index =
    let
        tagField =
            Form.textField
                { parser = Ok
                , value = .tag
                , update = \value values -> { values | tag = value }
                , error = always Nothing
                , attributes =
                    { label = ""
                    , placeholder = "Ny tagg..."
                    }
                }
    in
    Form.succeed Tag |> Form.append tagField

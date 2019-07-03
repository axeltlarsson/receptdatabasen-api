module Session exposing (Session, fromKey, navKey)

import Browser.Navigation as Nav


type Session
    = Session Nav.Key


navKey : Session -> Nav.Key
navKey session =
    case session of
        Session key ->
            key


fromKey : Nav.Key -> Session
fromKey key =
    Session key

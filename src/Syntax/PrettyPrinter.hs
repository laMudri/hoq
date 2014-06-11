module Syntax.PrettyPrinter
    ( ppTerm, ppDef, ppPattern
    ) where

import Text.PrettyPrint
import Data.Foldable

import Syntax.Term
import qualified ErrorDoc as E

instance E.Pretty Term where
    pretty t = ppTermCtx (map (\s -> (s,0)) (toList $ fmap render t)) t

ppPattern :: Pattern Doc -> Doc
ppPattern (Pattern v pats) = v <+> hsep (map (parens . ppPattern) pats)

ppDef :: String -> Def String -> Doc
ppDef n d = text n <+>     colon  <+> ppTerm (defType d)
         $$ text n <+> case d of
            Def _ cases -> vcat $ flip map cases $ \(Name pats term) ->
                           hsep (map (parens . ppPattern . fmap text) pats) <+>
                           equals <+> ppTerm (instantiate (\i -> Var $ toList (Pattern n pats) !! i) term)
            Syn _ term  -> equals <+> ppTerm term

ppTerm :: Term String -> Doc
ppTerm t = ppTermCtx (map (\s -> (s,0)) (toList t)) (fmap text t)

ppTermCtx :: [(String,Int)] -> Term Doc -> Doc
ppTermCtx _ (Var d) = d
ppTermCtx _ (Universe l) = text $ "Type" ++ show l
ppTermCtx ctx t@(App e1 e2) = ppTermPrec (prec t) ctx e1 <+> ppTermPrec (prec t + 1) ctx e2
ppTermCtx ctx t@(Arr e1 e2) = ppTermPrec (prec t + 1) ctx e1 <+> arrow <+> ppTermPrec (prec t) ctx e2
ppTermCtx ctx t@(Pi b e n) =
    let (as, t') = ppNamesPrec (prec t) ctx n
    in parens (hsep as <+> colon <+> ppTermCtx ctx e) <+> (if b then arrow else empty) <+> t'
ppTermCtx ctx t@(Lam n) =
    let (as, t') = ppNamesPrec (prec t) ctx n
    in text "\\" <> hsep as <+> arrow <+> t'
ppTermCtx ctx t@(Con _ n as) = text n <+> hsep (map (ppTermPrec (prec t + 1) ctx) as)
ppTermCtx _ (FunSyn n _) = text n
ppTermCtx _ (FunCall n _) = text n

ppNamesPrec :: Int -> [(String,Int)] -> Names String Term Doc -> ([Doc], Doc)
ppNamesPrec p ctx n =
    let (as, ctx', t) = instantiateNames ctx (\d -> maybe (text d) $ \i -> text d <> int i) n
    in (as, ppTermPrec p ctx' t)

ppTermPrec :: Int -> [(String,Int)] -> Term Doc -> Doc
ppTermPrec p ctx t = if p > prec t then parens (ppTermCtx ctx t) else ppTermCtx ctx t

arrow :: Doc
arrow = text "->"

prec :: Term a -> Int
prec Var{}        = 10
prec Universe{}   = 10
prec FunSyn{}     = 10
prec FunCall{}    = 10
prec (Con _ _ []) = 10
prec App{}        = 9
prec Con{}        = 9
prec Arr{}        = 8
prec Pi{}         = 8
prec Lam{}        = 8

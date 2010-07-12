{-# LANGUAGE TypeSynonymInstances, TemplateHaskell #-}
-----------------------------------------------------------------------------
{- |
Module      :  EasyVision.GUI.Parameters
Copyright   :  (c) Alberto Ruiz 2006
License     :  GPL-style

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  very provisional
Portability :  hmm...

A \'global\' parameter list with its own control window. See the example warp.hs.

-}
-----------------------------------------------------------------------------

module EasyVision.GUI.Parameters (
   Parameters,
   createParameters, createParameters', autoParam,
   listParam, realParam, floatParam, percent, intParam, stringParam,
   getParam, info, posi, incre, decre, setpo
) where

import ImagProc.Ipp.Core
import EasyVision.GUI.GUI
import Graphics.UI.GLUT hiding (RGB, Matrix, Size)
import qualified Graphics.UI.GLUT as GL
import Data.IORef
import qualified Data.Map as Map
import Data.Map hiding (map)
import GHC.Float
import Numeric
import Data.List(elemIndex,foldl')
import Control.Monad(ap)

import Language.Haskell.TH
import Language.Haskell.TH.Syntax
import GHC.Types(Double)

sizePar = 35

-- | Given an assoc list of names and initial values of some \'global\' application parameters, it creates a window for controlling them and returns a function to get the current value of the desired parameter. There are several types of parameters.
createParameters :: [(String, Parameter)]
                 -> IO (EVWindow (Map String Parameter))
createParameters = createParameters' "Parameters"

createParameters' winname ops = do
    evWindow (Map.fromList ops) 
             winname 
             (Size (2+length ops * sizePar) 200)
             (Just f)
             (kbdopts kbdQuit)

  where
    f o = do
        m <- readIORef o
        let els = Map.elems m
        pixelCoordinates (Size (2+length els * sizePar) 200)

        sequence_ $ zipWith bar [0..] (assocs m)
        return ()

    bar p (s,e) = do
        setColor 0 0 0.5
        renderPrimitive Polygon (mapM_ vertex [Pixel r1 c1,
                                                        Pixel r1 c2,
                                                        Pixel r2 c2,
                                                        Pixel r2 c1])
        setColor 1 1 1
        rasterPos (Vertex2 (5::GLfloat) (4+fromIntegral r1/2+fromIntegral r2/2))
        renderString Helvetica12 (s++" = "++info e)
      where r1 = 2+p*sizePar
            r2 = 2+p*sizePar+(sizePar -2)
            c1 = 1
            c2 = 2*k
            k = posi e

    kbdopts def opts = kbd where
        kbd (MouseButton WheelUp) Down _ pos@(Position x y) = do
            m <- readIORef opts
            let s' = keys m
            let s = (s' !! (fromIntegral y `div` sizePar))
            let v = m!s 
            let m' = insert s (incre v) m
            writeIORef opts m'
            postRedisplay Nothing
        kbd (MouseButton WheelDown) Down _ pos@(Position x y) = do
            m <- readIORef opts
            let s' = keys m
            let s = (s' !! (fromIntegral y `div` sizePar))
            let v = m!s 
            let m' = insert s (decre v) m
            writeIORef opts m'
            postRedisplay Nothing
        kbd (MouseButton LeftButton) Down _ pos@(Position x y) = do
            m <- readIORef opts
            let s' = keys m
            let s = (s' !! (fromIntegral y `div` sizePar))
            let v = m!s 
            let m' = insert s (setpo x v) m
            writeIORef opts m'
            postRedisplay Nothing
        kbd a b c d = def a b c d


type Parameters = IORef (Map String Parameter)

data Parameter = Percent Int
               | RealParam Double Double Double
               | FlagParam Bool
               | IntParam Int Int Int
               | StringParam { sPos :: Int, sVal :: String, sList :: [String] }
               | RLParam { rVal:: Double,
                           rPos :: Int,
                           rMin,rMax :: Double,
                           rList :: [Double],
                           rLength :: Int }
               deriving Show

-- | Creates a 'Parameter' of type Double, with initial value and a list of allowed values (in ascending order).
listParam :: Double -> [Double] -> Parameter
listParam v list = RLParam {rVal = list!!k,
                            rPos = k,
                            rMin = head list,
                            rMax = last list,
                            rList = list,
                            rLength = length list}
   where k = (length $ fst $ span (< v) list)

-- | Creates a 'Parameter' of type String, with initial value index and a list of allowed values.
stringParam :: String -> [String] -> Parameter
stringParam s list = StringParam { sVal = s
                                 , sPos = k
                                 , sList = list}
    where k = case elemIndex s list of
                Nothing -> error $ "option "++s++" is not in the list "++ show list
                Just p -> p

-- | Creates a 'Parameter' of type Int between 0 and 100.
percent :: Int -> Parameter
percent = Percent

-- | Creates a 'Parameter' of type Double, between a minimum and maximum value, with 100 divisions.
realParam :: Double -> Double -> Double -> Parameter
realParam = RealParam

-- | Creates a 'Parameter' of type Double (from float types), between a minimum and maximum value, with 100 divisions.
floatParam :: Float -> Float -> Float -> Parameter
floatParam a b c = realParam (float2Double a) (float2Double b) (float2Double c)

-- | Creates a 'Parameter' of type Int, between a minimum and maximum value
intParam :: Int -> Int -> Int -> Parameter
intParam = IntParam

incre (Percent v)   = Percent (min 100 (v+1))
incre (RealParam v a b)   = RealParam (min b (v+(b-a)/100)) a b
incre (IntParam v a b) = IntParam (min b (v+1)) a b
incre (x@RLParam {}) = x {rVal = rList x !! k, rPos = k}
    where k = min (rLength x -1) (rPos x + 1)
incre (x@StringParam {}) = x {sVal = sList x !! k, sPos = k}
    where k = (sPos x + 1) `rem` length (sList x)

decre (Percent v)   = Percent (max 0 (v-1))
decre (RealParam v a b)   = RealParam (max a (v-(b-a)/100)) a b
decre (IntParam v a b) = IntParam (max a (v-1)) a b
decre (x@RLParam {}) = x {rVal = rList x !! k, rPos = k}
    where k = max 0 (rPos x - 1)
decre (x@StringParam {}) = x {sVal = sList x !! k, sPos = k}
    where k = max 0 (sPos x - 1)

setpo p (Percent _) = Percent (fromIntegral p `div` 2)
setpo p (RealParam v a b) = RealParam (a+(b-a)/100*fromIntegral p / 2) a b
setpo p (IntParam v a b) = IntParam (a+ round (fromIntegral (b-a)*fromIntegral p / 200)) a b
setpo p (x@RLParam {}) = x {rVal = rList x !! k, rPos = k}
    where k = round $ (fromIntegral $ rLength x) * fromIntegral p / 200
setpo p (x@StringParam {}) = x {sVal = sList x !! k, sPos = k}
    where k = round $ (fromIntegral $ length $ sList x) * fromIntegral p / 200


posi (Percent v)    = v
posi (RealParam v a b)    = round $ 100*(v-a)/(b-a)
posi (IntParam v a b)   = round $ 100*fromIntegral (v-a)/fromIntegral(b-a)
posi (RLParam {rPos = i, rLength = l}) = (200*i) `div` (2*(l-1))
posi (StringParam {sPos = i, sList = list}) = (200*i) `div` (2*(l-1))
    where l = length list

info (Percent v) = show v ++ "%"
info (RealParam v _ _) = showFFloat (Just 2) v ""
info (RLParam {rVal = v}) = showFFloat (Just 2) v ""
info (IntParam v _ _) = show v
info (StringParam {sVal = s}) = s

class Param a where
    param :: Parameter -> a
    -- | Extracts a parameter given its name.
    getParam :: EVWindow (Map String Parameter) -> String -> IO a
    getParam w s = do
        m <- getW w
        return $ param $ m!s

instance Param Int where
    param (Percent v) = v
    param (IntParam v _ _) = v
    param (StringParam {sPos = k}) = k
    param v = error $ "wrong param conversion from "++ show v ++ " to Int"


instance Param Double where
    param (RealParam v _ _) = v
    param (RLParam {rVal = v}) = v
    param v = error $ "wrong param conversion from "++ show v ++ " to Double"

instance Param Float where
    param (RealParam v _ _) = double2Float v
    param (RLParam {rVal = v}) = double2Float v
    param v = error $ "wrong param conversion from "++ show v ++ " to Float"

instance Param String where
    param (StringParam {sVal = s}) = s
    param v = error $ "wrong param conversion from "++ show v ++ " to String"


-------------------------------------------------------

instance Lift Double where
    lift = liftD

liftD x = sigE a (conT ''GHC.Types.Double)
    where a = appE (varE 'read) (litE (stringL (show x)))

instance Lift Parameter where
    lift (Percent x) = conE 'Percent `appE` lift x
    lift (RealParam v a b) = conE 'RealParam `appE` liftD v `appE` liftD a `appE` liftD b
    lift (FlagParam x) = conE 'FlagParam `appE` lift x
    lift (IntParam v x y) = conE 'IntParam `appE` lift v `appE` lift x `appE` lift y
    lift (StringParam p v l) = conE 'StringParam `appE` lift p `appE` lift v `appE` lift l
    lift (RLParam v p mn mx l n) = conE 'RLParam
                                    `appE` liftD v `appE` lift p `appE` liftD mn `appE` liftD mx
                                    `appE` lift l `appE` lift n 

---------------------------------------------------------


mkField (n,t) = varStrictType (mkName n) $ strictType notStrict (conT (mkName t))

createRec name fields = dataD (cxt[]) (mkName name) [] [recC (mkName name) (map mkField fields)] []

autoParam name funname defpar = sequence [createRec name fields,
                                  valD (varP (mkName funname))
                                       (normalB (doE [ bindS (varP (mkName "o")) (appE (varE 'createParameters) (lift x))
                                                     , noBindS (appE (varE 'return) f)])) [] ]
    where f = foldl' appp (appE (varE 'return) (conE p)) args
          args = map (g.lift.fst) x
          g = appE (appE (varE 'getParam) (varE (mkName "o")))
          x = map s13 defpar
          fields = map s12 defpar
          p = mkName name 
          s12 (a,b,c) = (a,b)
          s13 (a,b,c) = (a,c)

appp f x = appE (appE (varE 'ap) f) x

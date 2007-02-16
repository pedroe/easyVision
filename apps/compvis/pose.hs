
module Main where

import EasyVision
import Graphics.UI.GLUT hiding (Matrix,Size,Point)
import Data.IORef
import System.Exit
import Control.Monad(when)
import System.Environment(getArgs)
import Data.List(minimumBy)
import GSL hiding (size)
import Vision

vector v = fromList v :: Vector Double

data MyState = ST { imgs :: [ImageFloat]
                  , corners, marked ::[Pixel]
                  , pts  :: [[Point]]
                  , cams :: [Matrix Double]
                  , drfuns :: [IO()]

                  , basev ::Int

                  , trackball :: IO ()
                  , camera :: IO ImageYUV
                  }

diagl = diag . vector

--------------------------------------------------------------
main = do
    args <- getArgs
    let sz = Size 288 384
    (cam,ctrl) <- mplayer (args!!0) sz >>= withPause

    (tb,kc,mc) <- newTrackball

    state <- prepare ST { imgs=[]
                        , corners=[], marked = []
                        , pts=[]
                        , cams=[]
                        , drfuns=[]
                        , basev = 0
                        , trackball = tb
                        , camera = cam
                        }

    addWindow "camera" sz Nothing (marker (const (kbdcam ctrl))) state
    addWindow "selected" sz Nothing keyboard state

    addWindow "3D view" (Size 400 400) Nothing keyboard state
    keyboardMouseCallback $= Just (kc (keyboard state))
    motionCallback $= Just mc
    depthFunc $= Just Less

    textureFilter Texture2D $= ((Nearest, Nothing), Nearest)
    textureFunction $= Decal
    launch state (worker cam)

-------------------------------------------------------------------
a4 = [[   0,    0]
     ,[   0, 2.97]
     ,[2.10, 2.97]
     ,[2.10,    0]
     ]

pl (Point x y) = [x,y]
mpl = map pl

recover pts = c where
    h = estimateHomography (mpl pts) a4
    Just c = cameraFromHomogZ0 Nothing h

worker grab inWindow st = do
    camera <- grab >>= yuvToGray >>= scale8u32f 0 1
    hotPoints <- getCorners 1 7 0.1 200 camera

    inWindow "camera" $ do
        drawImage camera
        pixelCoordinates (size camera)
        setColor 1 0 0
        pointSize $= 3
        renderPrimitive Points (mapM_ vertex hotPoints)
        setColor 0 0 1
        renderPrimitive Points (mapM_ vertex (marked st))


    let n = length (imgs st)

    when (n > 0) $ do
        let sel = basev st `rem` n
        let ps = pts st !! sel
        inWindow "selected" $ do
            drawImage $ imgs st !! sel
            pointCoordinates (Size 3 4)
            setColor 0.75 0 0
            renderPrimitive LineLoop (mapM_ vertex ps)
            pointSize $= 5
            renderPrimitive Points (mapM_ vertex ps)

        inWindow "3D view" $ do
            clear [ColorBuffer, DepthBuffer]
            trackball st

            setColor 0 0 1
            lineWidth $= 2
            renderPrimitive LineLoop (mapM_ vertex a4)

            setColor 1 1 1
            lineWidth $= 1
            sequence_ (drfuns st)

    return st {corners = hotPoints}


------------------------------------------------------

compareBy f = (\a b-> compare (f a) (f b))

closest [] p = p
closest hp p = minimumBy (compareBy $ dist p) hp
    where dist (Pixel a b) (Pixel x y) = (a-x)^2+(b-y)^2

-----------------------------------------------------------------
-- callbacks
-----------------------------------------------------------------

keyboard st (SpecialKey KeyUp) Down _ _ = do
    modifyIORef st $ \s -> s {ust = (ust s) {basev = basev (ust s) + 1}}
keyboard st (SpecialKey KeyDown) Down _ _ = do
    modifyIORef st $ \s -> s {ust = (ust s) {basev = max (basev (ust s) - 1) 0}}

keyboard _ _ _ _ _ = return ()

------------------------------------------------------------------

marker def str (MouseButton LeftButton) Down _ pos@(Position x y) = do
    st <- readIORef str
    let u = ust (st)
    let newpoint = closest (corners u) (Pixel (fromIntegral y) (fromIntegral x))
    let m = newpoint : marked u
    if (length m /= 4)
        then writeIORef str st { ust = u {marked = m} }
        else do
            orig <- camera (ust st) >>= yuvToGray
            let hp = reverse $ pixelsToPoints (size orig) m
            im  <- scale8u32f 0 1 orig
            let cam = recover hp
            imt <- extractSquare 128 im
            let v = u { marked = []
                       , imgs = imgs u ++ [im]
                       , pts = pts u ++ [hp]
                       , cams = cams u ++ [cam]
                       , drfuns = drfuns u ++ [drawCamera 1 cam (Just imt)]
                       }
            writeIORef str st { ust = v }

marker def st (MouseButton RightButton) Down _ pos@(Position x y) = do
    modifyIORef st $ \s -> s {ust = (ust s) {marked = case marked (ust s) of
                                                        [] -> []
                                                        _:t -> t }}

marker def st b s m p = def st b s m p

{-# OPTIONS -fglasgow-exts #-}
-----------------------------------------------------------------------------
{- |
Module      :  GSL.Utils
Copyright   :  (c) Alberto Ruiz 2006
License     :  GPL-style

Maintainer  :  Alberto Ruiz (aruiz at um dot es)
Stability   :  provisional
Portability :  uses -fffi and -fglasgow-exts

Utility functions easily derivable from the basic ones in "GSL".

-}
-----------------------------------------------------------------------------

module GSL.Utils (
    -- * Easy creation of vectors and matrices
    realVector, realMatrix, complexVector, complexMatrix, 
    -- * Matrix IO
    fromFile, toFile, gslReadMatrix,
    -- * Special matrices
    ident, constant, hilb, 
    -- * Additional matrix manipulation
    extractRows, fromRows, toRows, fromCols, toCols, flipud, fliprl,
    vmap, mmap, vzip, mzip, 
    -- * Drawing 
    -- | Currently we use external tools like gnuplot and imageMagick; we will eventually use HGL and HOpengGL. Some function names (after Octave) are not very informative...
    plot, parametricPlot, mplot, 
    splot, mesh, meshdom, 
    matrixToPGM, imshow,
    -- * Other
     i, norm, (//), disp, sumCols, outer, linspace
) where

import GSL.Core
import GSL.Wrappers
import GSL.Derived
import GSL.Interface
import GSL.Drawing
import Foreign
import Complex
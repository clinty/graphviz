{-# LANGUAGE TypeSynonymInstances, FlexibleInstances #-}

{- |
   Module      : Data.GraphViz.Attributes
   Description : User-friendly wrappers around Graphviz attributes.
   Copyright   : (c) Matthew Sackman, Ivan Lazar Miljenovic
   License     : 3-Clause BSD-style
   Maintainer  : Ivan.Miljenovic@gmail.com

   There are almost 150 possible attributes available for Dot graphs, and
   it can be difficult to know which ones to use.  This module provides
   helper functions for the most commonly used ones.

   The complete list of all possible attributes can be found in
   "Data.GraphViz.Attributes.Complete"; it is possible to use both of
   these modules if you require specific extra attributes that are not
   provided here.

 -}
module Data.GraphViz.Attributes
       ( -- * The definition of attributes
         Attribute
       , Attributes
         -- * Creating labels
         -- $labels
       , toLabel
       , textLabel
       , xLabel
       , xTextLabel
       , forceLabels
       , textLabelValue
       , Labellable(..)
         -- * Colors
         -- $colors
       , X11Color(..)
       , bgColor
       , fillColor
       , fontColor
       , penColor
       , color
         -- * Stylistic attributes
         -- $styles
       , penWidth
       , style
       , styles
       , Style
       , dashed
       , dotted
       , solid
       , bold
       , invis
       , filled
       , diagonals
       , rounded
       , tapered
         -- * Node shapes
       , shape
       , Shape(..)
         -- * Edge arrows
       , arrowTo
       , arrowFrom
         -- ** Specifying where to draw arrows on an edge.
       , edgeEnds
       , DirType(..)
         -- ** Default arrow types.
       , Arrow
         -- *** The 9 primitive arrows.
       , box
       , crow
       , diamond
       , dotArrow
       , inv
       , noArrow
       , normal
       , tee
       , vee
         -- *** 5 derived arrows.
       , oDot
       , invDot
       , invODot
       , oBox
       , oDiamond
         -- * Layout
       , ordering
       , Order(..)
       ) where

import Data.GraphViz.Attributes.Complete

import qualified Data.Text.Lazy as T
import Data.Text.Lazy(Text)

-- -----------------------------------------------------------------------------

{- $labels

   The following escape codes are available for labels (where applicable):

     [@\\N@] Replace with the name of the node.

     [@\\G@] Replace with the name of the graph (for node attributes)
             or the name of the graph or cluster, whichever is
             applicable (for graph, cluster and edge attributes).

     [@\\E@] Replace with the name of the edge, formed by the two
             adjoining nodes and the edge type.

     [@\\T@] Replace with the name of the node the edge is coming from.

     [@\\H@] Replace with the name of the node the edge is going to.

     [@\\n@] Centered newline.

     [@\\l@] Left-justified newline.

     [@\\r@] Right-justified newline.

 -}

-- | A convenience class to make it easier to create labels.  It is
--   highly recommended that you make any other types that you wish to
--   create labels from an instance of this class, preferably via the
--   @String@ or @Text@ instances.
class Labellable a where
  -- | This function only creates a 'Label' value to enable you to use
  --   it for 'Attributes' such as 'HeadLabel', etc.
  toLabelValue :: a -> Label

-- | Equivalent to @'Label' . 'toLabelValue'@; the most common label
--   'Attribute'.
toLabel :: (Labellable a) => a -> Attribute
toLabel = Label . toLabelValue

-- | An alias for 'toLabel' for use with the @OverloadedStrings@
--   extension.
textLabel :: Text -> Attribute
textLabel = toLabel

-- | Create a label /outside/ of a node\/edge.  Currently only in the
-- | Graphviz development branch (2.29.*).
xLabel :: (Labellable a) => a -> Attribute
xLabel = XLabel . toLabelValue

-- | An alias for 'xLabel' for use with the @OverloadedStrings@ extension.
xTextLabel :: Text -> Attribute
xTextLabel = xLabel

-- | Force the positioning of 'xLabel's, even when it will cause overlaps.
forceLabels :: Attribute
forceLabels = ForceLabels True

-- | An alias for 'toLabelValue' for use with the @OverloadedStrings@
--   extension.
textLabelValue :: Text -> Label
textLabelValue = toLabelValue

instance Labellable Text where
  toLabelValue = StrLabel

instance Labellable Char where
  toLabelValue = toLabelValue . T.singleton

instance Labellable String where
  toLabelValue = toLabelValue . T.pack

instance Labellable Int where
  toLabelValue = toLabelValue . show

instance Labellable Double where
  toLabelValue = toLabelValue . show

instance Labellable Bool where
  toLabelValue = toLabelValue . show

instance Labellable HtmlLabel where
  toLabelValue = HtmlLabel

instance Labellable HtmlText where
  toLabelValue = toLabelValue . HtmlText

instance Labellable HtmlTable where
  toLabelValue = toLabelValue . HtmlTable

instance Labellable RecordFields where
  toLabelValue = RecordLabel

instance Labellable RecordField where
  toLabelValue = toLabelValue . (:[])

-- | A shorter variant than using @PortName@ from 'RecordField'.
instance Labellable PortName where
  toLabelValue = toLabelValue . PortName

-- | A shorter variant than using 'LabelledTarget'.
instance Labellable (PortName, EscString) where
  toLabelValue = toLabelValue . uncurry LabelledTarget

-- -----------------------------------------------------------------------------

{- $colors

   The recommended way of dealing with colors in Dot graphs is to use the
   named 'X11Colors' rather than explicitly specifying RGB, RGBA or HSV
   colors.

 -}

-- | Specify the background color of a graph or cluster.  Requires
--   @'style' 'filled'@.
bgColor :: X11Color -> Attribute
bgColor = BgColor . X11Color

-- | Specify the fill color of a node.  Requires @'style' 'filled'@.
fillColor :: X11Color -> Attribute
fillColor = FillColor . X11Color

-- | Specify the color of text.
fontColor :: X11Color -> Attribute
fontColor = FontColor . X11Color

-- | Specify the color of the bounding box of a cluster.
penColor :: X11Color -> Attribute
penColor = PenColor . X11Color

-- | The @color@ attribute serves several purposes.  As such care must
--   be taken when using it, and it is preferable to use those
--   alternatives that are available when they exist.
--
--   * The color of edges;
--
--   * The bounding color of nodes;
--
--   * The bounding color of clusters (i.e. equivalent to 'penColor');
--
--   * If the 'filled' 'Style' is set, then it defines the
--     background color of nodes and clusters unless 'fillColor' or
--     'bgColor' respectively is set.
color :: X11Color -> Attribute
color = Color . (:[]) . X11Color

-- -----------------------------------------------------------------------------

{- $styles

   Various stylistic attributes to customise how items are drawn.
   Unless specified otherwise, all 'Style's are available for nodes;
   those specified also can be used for edges and clusters.

 -}

-- | A particular style type to be used.
type Style = StyleItem

style :: Style -> Attribute
style = styles . (:[])

styles :: [Style] -> Attribute
styles = Style

-- | Also available for edges.
dashed :: Style
dashed = SItem Dashed []

-- | Also available for edges.
dotted :: Style
dotted = SItem Dotted []

-- | Also available for edges.
solid :: Style
solid = SItem Solid []

-- | Also available for edges.
invis :: Style
invis = SItem Invisible []

-- | Also available for edges.
bold :: Style
bold = SItem Bold []

-- | Also available for clusters.
filled :: Style
filled = SItem Filled []

-- | Also available for clusters.
rounded :: Style
rounded = SItem Rounded []

-- | Only available for nodes.
diagonals :: Style
diagonals = SItem Diagonals []

-- | Only available for edges; creates a tapered edge between the two
--   nodes.  Currently only available in the development branch of
--   Graphviz (2.29.*).
tapered :: Style
tapered = SItem Tapered []

-- | Specify the width of lines.  Valid for clusters, nodes and edges.
penWidth :: Double -> Attribute
penWidth = PenWidth

-- -----------------------------------------------------------------------------

-- | The shape of a node.
shape :: Shape -> Attribute
shape = Shape

-- -----------------------------------------------------------------------------

-- | A particular way of drawing the end of an edge.
type Arrow = ArrowType

-- | How to draw the arrow at the node the edge is pointing to.  For
--   an undirected graph, requires either @'edgeEnds' 'Forward'@ or
--   @'edgeEnds' 'Both'@.
arrowTo :: Arrow -> Attribute
arrowTo = ArrowHead

-- | How to draw the arrow at the node the edge is coming from.
--   Requires either @'edgeEnds' 'Back'@ or @'edgeEnds' 'Both'@.
arrowFrom :: Arrow -> Attribute
arrowFrom = ArrowTail

-- | Specify where to place arrows on an edge.
edgeEnds :: DirType -> Attribute
edgeEnds = Direction

box, crow, diamond, dotArrow, inv, noArrow, normal, tee, vee :: Arrow
oDot, invDot, invODot, oBox, oDiamond :: Arrow

normal = AType [(noMods, Normal)]
inv = AType [(noMods, Inv)]
dotArrow = AType [(noMods, DotArrow)]
invDot = AType [ (noMods, Inv)
               , (noMods, DotArrow)]
oDot = AType [(ArrMod OpenArrow BothSides, DotArrow)]
invODot = AType [ (noMods, Inv)
                , (openMod, DotArrow)]
noArrow = AType [(noMods, NoArrow)]
tee = AType [(noMods, Tee)]
diamond = AType [(noMods, Diamond)]
oDiamond = AType [(openMod, Diamond)]
crow = AType [(noMods, Crow)]
box = AType [(noMods, Box)]
oBox = AType [(openMod, Box)]
vee = AType [(noMods, Vee)]

-- -----------------------------------------------------------------------------

-- | Specify an ordering of edges of a node: either the outgoing or
--   the incoming edges of a node must appear left-to-right in the
--   same order in which they are defined in the input.
--
--   When specified as both a global graph or sub-graph level
--   attribute, then it takes precedence over an attribute specified
--   for an individual node.
ordering :: Order -> Attribute
ordering = Ordering

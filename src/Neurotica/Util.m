(* Util.m
 *
 * Basic utility functions, e.g. for automatically caching data in quick-to-load mx files.
 *
 * Copyright (C) 2014-2015 by Noah C. Benson.
 * This file is part of the Neurotica library.
 *
 * This program is free software: you can redistribute it and/or modify it under the terms of the
 * GNU General Public License as published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
 * without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
 * the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.
 * If not, see <http://www.gnu.org/licenses/>.
 *)

(**************************************************************************************************)
BeginPackage["Neurotica`Util`", {"Neurotica`Global`"}];
Unprotect["Neurotica`Util`*", "Neurotica`Util`Private`*"];
ClearAll ["Neurotica`Util`*", "Neurotica`Util`Private`*"];

(* If this is running on Mathematica prior to 10.2, add in the MissingQ function *)
If[$VersionNumber < 10.2 && !ValueQ[MissingQ[Null]],
  MissingQ::usage = "MissingQ[expr] gives True if expr has head Missing."];

Quote::usage = "Quote[expr] is identical to Hold[expr] except that it evaluates all of the statements inside expr that are wrapped in Eval. The return value of Quote[x] always has the head Quote. Note that if an Eval[_] form yields a Quote[_] form, then the (unevaluated) contents of the quote are inserted instead of the Quote form itself; this is not the case with Hold[_] forms, however.";
Eval::usage = "Eval[expr], when inserted anywhere into a Quote[...] form, causes the given expr's value in the current contex instead of its literal full-form. If the result of evaluating Eval[expr] matches Quote[expr_], then expr instead of Quote[expr] is inserted. To avoid this, return a Hold[_] expression instead.";
HoldQ::usage = "HoldQ[expr] is identical to Quote[expr] except that the head of the return value is Hold instead of Quote.";

FailMessage::usage = "FailMessage[tag, tmpl, args...] is equivalent to (Message[tmpl, args]; Failure[tag, <|\"MessageTemplate\" -> tmpl, \"MessageParameters\" -> args|>]).";

$CacheDirectory::usage = "$CacheDirectory is the directory in which cached data for this user is placed. If the directory does not exist at cache time and $AutoCreateCacheDirectory is True, then this directory is automatically created. By default it is the directory FileNameJoin[{$UserBaseDirectory, \"AutoCache\"}]. If set to Temporary, then the next use of AutoCache will create a temporary directory and set the $CacheDirectory to this path.";

$AutoCreateCacheDirectory::usage = "$AutoCreateCacheDirectory is True if and only if the $CacheDirectory should be automatically created when AutoCache requires it.";

AutoCache::usage = "AutoCache[name, body] checks first to see if a cache file exist for the file named by the given name and yields its contents if so. Otherwise, yields the result of evaluating body and caches it in the given filename. If the cache file is out of date relative to the evaluating cell, the contents are erased and recalculated. If the given filename is an absolute path, it is used as such, otherwise it is localized to the cache directory. Note that the mx extension is added automatically if not included.
The following options may be used:
 * Quiet (default: False) prevents the function from producing messages when updating or overwriting the cache file if False.
 * Check (default: True) if True instructs AutoCache to yield $Failed and not generate the cache file whenever messages are produced during the execution of body.
 * Directory (default: Automatic) names the directory in which the cache file should go; if Automatic, then uses $CacheDirectory.
 * CreateDirectory (default: Automatic) determines whether AutoCache can automatically create the $CacheDirectory if it is needed. If True, then AutoCache will always create the directory; if False it will never create the directory; if Automatically, it will defer to $AutoCreateCacheDirectory.
See also $AutoCacheEvaluateQ.";
AutoCache::expired = "AutoCache file `1` has expired; recalculating";
AutoCache::nodir = "AutoCache directory (`1`) does not exist and cannot be created";
AutoCache::nomkdir = "AutoCache directory (`1`) does not exist and AutoCache is not allowed to create it";
AutoCache::badopt = "Bad option to AutoCache: `1`"

$AutoCacheEvaluateQ::usage = "If the $AutoCacheEvaluateQ variable is set to anything but True, then calls to AutoCache will never evaluate the body and will return $Failed if such a point is reached. They will still return valid results if the data is already cached. In this sense, the variable can be used to load a cached result if it exists and fail if it does not.";

AutoCacheFilename::usage = "AutoCacheFilename[name] yields the filename that would be used to store the auto-cache with the given name.
AutoCacheFilename accepts the same arguments, Directory and CreateDirectory, as AutoCache and will create directories is specified.";

AutoCachedQ::usage = "AutoCachedQ[name] yields True if and only if the given cache exists in the AutoCache directories.
The Directory option may be passed as with AutoCache.";

SetSafe::usage = "SetSafe[a, b] is equivalent t0 the expression (a = b) except that if any messages are generated during the evaluation of b, $Failed is yielded and a is not set.";

Memoize::usage = "Memoize[f := expr] constructs a version of the pattern f that will auto-memoize its values and remember them.
Memoize[\!\(\*SubscriptBox[\(f\),\(1\)]\) := \!\(\*SubscriptBox[\(expr\),\(1\)]\), \!\(\*SubscriptBox[\(f\),\(2\)]\) := \!\(\*SubscriptBox[\(expr\),\(2\)]\), ...] memoizes each of the given functions.
The function Forget may be used to forget the memoized values of functions defined within a Memoize form.";
MemoizeSafe::usage = "MemoizeSafe[f := expr, ...] is identical to calling Memoize except that it uses SetSafe instead of Set to memoize values, so of the evaluation of the expression fails or generates a message, the result is not memoized and $Failed is yielded.";
Forget::usage = "Forget[f] forces all memoized values associated with the symbol f to be forgotten.
Forget[\!\(\*SubscriptBox[\(f\),\(1\)]\), \!\(\*SubscriptBox[\(f\),\(2\)]\), ...] forgets each of the symbols.";

AutoManageData::usage = "AutoManageData[patt1 := form1, ...] defines the given patterns in such a way that, if the result takes longer than a second to calculate, it is automatically memoized, and, if it takes longer than 4 seconds to calculate, it is automatically cached. The exact timeout requirements can be manipulated with the options.

Options:
  * AutoMemoizeAfter (default: 0) is the number of seconds a calculation must take in order to be memoized.
  * AutoCacheAfter (default: 1) is the number of seconds a calculation must take in order to be cached.
  * Directory (default: Automatic) is passed to the AutoCache[] function to determine the directory.";
AutoMemoizeAfter::usage = "AutoMemoizeAfter is an option for AutoManageData[] that specifies the number of seconds a calculation should be allowed to take without getting memoized. In other words, if a calculation declared inside an AutoManageData[...] form takes longer than <AutoMemoizeAfter> seconds, it is automatically memoized.";
AutoCacheAfter::usage = "AutoCacheAfter is an option for AutoManageData[] that specifies the number of seconds a calculation should be allowed to take without getting cached. In other words, if a calculation declared inside an AutoManageData[...] form takes longer than <AutoCachefter> seconds, it is automatically cached.";
$AutoMemoizeAfter::usage = "$AutoMemoizeAfter is the default value of the AutoMemoizeAfter option for AutoManageData[].";
$AutoCacheAfter::usage = "$AutoCacheAfter is the default value of the AutoCacheAfter option for AutoManageData[].";

Indices::usage = "Indices[list, patt] yields a list of the indices of elements that match patt in list; this is equivalent to Flatten[Position[list, patt, {1}, Heads->False]], but is considerably optimized.";
IndexList::usage = "IndexList[list] yields an association containing, as keys, each unique element that occurs in the given list and, as values, the indices at which the corresponding element occurs in the list. For example, IndexList[{a,b,c,b}] == <|a -> {1}, b -> {2,4}, c -> {3}|>.";

TemporarySymbol::usage = "TemporarySymbol[] yields a unique symbol that is marked as temporary.
TemporarySymbol[string] yields a unique symbol that begins with the given string and is marked temporary.";

DefineImmutable::usage = "DefineImmutable[constructor[args...] :> symbol, {members...}] defines an immutable data type with the given constructor and the accessor functions given by the list of members. Each member must be of the form (f[symbol] ** form) where f is the function that is used to access the data, the form yields the value and may refer to the arguments of the constructor or the other member functions, and ** must be either =, ->, :>, or :=, each of which is interpreted differently:
 * any value assigned with a := will become a generic function whose value is calculated each time the function is called;
 * any value assigned with a :> rule becomes a function that is memoized for each object once it has been calculated; note, however, that memoized values in an immutable object cannot be forgotted by the Forget[] function;
 * any value assigned with a -> rule will be calculated and saved to the object when it is constructed;
 * any value assigned with a = will also be assigned when the object is constructed, just as with the -> rule forms; however, values assigned with an = form may be modified in the Clone[] function.
In addition, the functions assigned using the := form may have additional arguments, as long as the first argument is the symbol.
DefineImmutable[constructor[args...] :> symbol, Hold[members...]] is identical to DefineImmutable[constructor[args...] :> symbol, {members...}].
The following options may be given:
 * Symbol (default: Automatic) specifies the box form used to hold the type; if no box type is given, then a unique symbol is generated to encapsulate the type.
 * SetSafe (default: True) specifies whether memoization performed on :> rule forms should be done using SetSafe (True) or Set (False).
See also Clone.";
DefineImmutable::badarg = "Bad argument given to DefineImmutable: `1`";
Clone::usage = "Clone[immutable, edits...] yields an immutable object (created via a constructor defined by the DefineImmutable interface) identical to the given object immutable with the changes given by the sequence of edits. Each edit must take the form accessor -> value where accessor is the function name for a member assigned using an = form in the DefineImmutable function and value is the new value it should take.";
Clone::badarg = "Bad argument given to Clone: `1`";

Let::usage = "Let[{bindings...}, body] is similar to With, Module, and Block, but includes the following features:
  * Each binding may refer to any binding that precedes it in the list of bindings.
  * Bindings of the form symbol = form may be reassigned in the body (like a Module binding).
  * Bindings of the form symbol -> form may not be reassigned in the body (like a With binding).
  * Bindings of the form symbol := form may be reassigned but are initially assigned using SetDelayed.
  * Bindings of the form symbol :> form may not be reassigned, but are not assigned until requested, then are memoized.";

NormalizeRows::usage = "NormalizeRows[X] yields a transformation of the matrix X in which each row of X has been normalized; this is the equivalent of (Normalize /@ X) but is significantly optimized.";
NormalizeColumns::usage = "NormalizeColumns[X] yields a transformation of the matrix X in which each column of X has been normalized. This is equivalent to Transpose[Normalze /@ Transpose[X]], but has been significantly optimized.";
RowNorms::usage = "RowNorms[X] yields the equivalent of Norm /@ X.";
ColumnNorms::usage = "ColumnNorms[X] yields the equivalent of Norm /@ Transpose[X] but has been optimized for speed.";

QuaternionToRotationMatrix::usage = "QuaternionToRotationMatrix[{x,y,z,w}] yields the rotation matrix associated with the quaternion {x,y,z,w}.
QuaternionToRotationMatrix[{y, z, q}] is equivalent to QuaternionToRotationMatrix[{x,y,z,q}] where x is Sqrt[1 - (x^2 + y^2 + z^2)].";

ReadBinaryStructure::usage = "ReadBinaryStructure[stream, instructionsList] yields the data structure result of importing the given instructions via BinaryReadList. Instructions may take the following format:
  * type (e.g., \"Integer32\" or \"Real64\") are read as is;
  * {type, n} reads in a list of n of the given type (if n is 1 then a 1-element list is returned);
  * {type, n, postprocessFn} yields postprocessFn[data] where data is the list of n of the given type;
  * name -> spec yields the rule name -> result where result is the result of reading in the given instruction spec;
  * {spec1, spec2...} yields a list of the given instruction specs, each read in order.";
ReadBinaryStructure::badinstr = "Bad instruction given to ReadBinaryStructure: `1`";

BinaryStringFix::usage = "BinaryStringFix[{c1, c2, ...}] yields the string formed from the given list of characters, truncating the string upon encountering the first null character (character code 0).";

NeuroticaPermanentDatum::usage = "NeuroticaPermanentDatum[name, value] yields Null but adds the given name/value pair to the current user's Neurotica auto-initialization file. The data contained in this file are loaded at startup and must consist only of string data. The file itself is stored as a \"Table\" style file at FileNameJoin[{$UserBasePath, \".NeuroticaPermanentData.dat\"}].
If the value given in the second argument is None, then the datum is removed from the permanent cache.
NeuroticaPermanentDatum[name] yields the value of the permanent datum with the given name; if no such datum is found, then None is returned.";

FlipIntegerBytes::usage = "FlipIntegerBytes[i] yields a version of the integer i such that the bytes are interpreted in reverse order; i.e., switches between Big and Little Endian.
FlipIntegerBytes[i, k] treats i as a k-byte integer; k may be a number (e.g., 4 for a 32-bit integer) or a data type (e.g., \"Integer32\" for a 32-bit integer).
FlipIntegerBytes[i] is equivalent to FlipIntegerBytes[i, \"Integer32\"].";
FlipIntegerBytes::badarg = "Bad argument given to FlipIntegerBytes: `1`";

Unboole::usage = "Unboole[u] yields a value or list the same length as the list u in which all zero elements have been converted to False and all non-zero elements have been converted to True; effectively this is the opposite of the Boole function. Unboole automatically threads over lists.
Note: If the argument to Unboole is not a real number or an integer, then Unboole yields a Piecewise function that checks for the argument == 0.";

MapNamed::usage = "MapNamed[f, {name1 -> list1, name2 -> list2, ...}] is identical to MapThread[f, {list1, list2...}] except that instead of passing the members of the various lists as the first, second, etc. argument to f, MapNamed passes a single Association argument to f with the appropriate values named according to the names in the given list.
MapNamed[f, name -> list] is equivalent to MapNamed[f, {name -> list}].
MapNamed[f, {data...}, level] applies f to the given level of the lists in data (equivalent to MapThread's use of level).
MapNamed[f, name -> list, level] also applies f to the given level, but expects level to be equivalent to the level passed to Map.";

DivideCheck::usage = "DivideCheck[a,b] yields a/b if Chop[b] is not equal to 0 and yields 0 if Chop[b] is equal to 0.
DivideCheck[a,b,c] yields c if Chop[b] is equal to 0.
Note that DivideCheck works with arrays as well as single values.";

FlatOuter::usage = "FlatOuter[args...] is identical to Outer[args...] except that it yields a 1D map that is equivalent to a flattened version of the latter form.";
FlatTable::usage = "FlatTable[args...] is identical to Table[args...] except that it yields a 1D map that is equivalent to a flattened version of the latter form.";

Iterate::usage = "Iterate[body, iterators...] is like Table[body, iterators...] except for two requirements of the iterators:
  * list iterators (such as Table[i^2, {i, {1, 4, 9}}]) cannot be used
  * iterators may be lists of iterators, in which the first element of the list is a normal Table-like iterator and the remaining iterators may not specify step-size; these iterators are bound such that they run from their min to their max over the sequence iterated in the first iterator.";
FlatIterate::usage = "FlatIterate[args...] is identical to Iterate[args...] except that it yeilds a 1D map that is equivalent to a flattened version of the latter form.";

WithOptions::usage = "WithOptions[f[args...], opts...] yields the result of calling the function f with the given arguments in args... followed by the options in the sequence of opts... where the options are filtered: WithOptions[f[args...], opts...] is equivalent to f[args..., Sequence@@FilterRules[{opts}, Options[f]].";

RenderMovie::usage = "RenderMovie[body, iterator] is essentially equivalent to Iterate[body, iterator] except that it takes into account several optional arguments. These arguments deal either with rendering or with frames.
 
Frames Options are specified by the arguments Frames, FrameRate, and Duration. If any of these arguments is not specified, an appropriate value will be chosen; if all are specified, they must agree (i.e., duration / frames = framerate). The duration prefers to be 6 seconds, 120 seconds in that order.
 
Rendering Options are specified by the arguments ImageResolution and Format. Format may be either Identity or Image; if Format is Imate, then an image is rendered at the given ImageResolution. Otherwise, the graphics objects themselves are returned.";
$FrameNumber::usage = "$FrameNumber is assigned the frame number in evaluation of the body during RenderMovie[] calls.";
$ElapsedTime::usage = "$ElapsedTime is the number of seconds that have elapsed in the movie during evaluation of the body during RenderMovie[] calls.";
RenderMovie::badarg = "Bad argument given to RenderMovie: `1`";
Frames::usage = "Frames is an argument to RenderMovie[] that specifies the number of frames.";
FrameRate::usage = "FrameRate is an argument to RenderMovie[] that specifies the number of frames per second.";
Duration::usage = "Duration is an argument to RenderMovie[] that specifies the duration of the movie.";

$NeuroticaPermanentData::usage = "$NeuroticaPermanentData is an Association of the permanent Neurotica data, as saved using the NeuroticaPermanentDatum function.";

(*
StatusReport::usage = "StatusReport[form] prints a temporary cell with the given form and yields a symbol q for which Value[q] is the given form, and, when assigned a value (q = val), changes the given form that is printed. The following options may be given:
  * Temporary - (default: True) indicates whether the returned symbol is a temporary symbol or not.
  * Style - (default: None) indicates the style of the given cell that is printed. If this is None, then no styling is added; the form is printed exactly as provided. Other values include Automatic (prints a blue box with the expression).
  * ";
*)

GaussianInterpolation::usage = "GaussianInterpolation[data] yields a function that performs the Gaussian-weighted mean interpolation over the given data matrix. The following options may be given:
  * StandardDeviation - the standard deviation of the Guassian filter to use
  * Threshold - the interpolation function is thresholded in that it only looks at the points close enough to be relevant. The threshold may be specified as a number (a distance cutoff), a list containing only an integer (always use the n closest points), or a list containing an integer followed by a distance cutoff.
  * VectorDifferenceFunction - in case the metric space is not Euclidean, this option must specify a function f that takes two vectors, u and v, and yields the vector subtraction of u from v; i.e., f[u, v] must be the vector from u to v. By default, this is (#2 - #1)&.
  * NormFunction - the function that yields the norm of a vector; by default, Norm.
  * Weights - the weights of the data; may be None to indicate equal weight given to each point. 
Additionally, all options that may be given to Nearest[] are accepted with the exception of DistanceFunction, which is replaced by the combination of VectorDifferenceFunction and NormFunction.";
GaussianInterpolation::badarg = "Bad argument given to GaussianInterpolation: `1`";
GaussianInterpolation::xdims = "Dimensions for given argument do not match those of interpolated space";
GaussianInterpolationFunction::usage = "GaussianInterpolationFunction[...] is a form used to store data related to a Gaussian-interpolated function.";

VectorDifferenceFunction::usage = "VectorDifferenceFunction is an option to GaussianInterpolation that must provide a function f such that, for vectors u and v, f[u, v] is the vector from u to v. By default, this is (#2 - #1)&.";
VectorScaleFunction::usage = "VectorScaleFunction is an option to GaussianInterpolation that must provide a function f such that, for vectors u and real r, f[u, r] is the vector in the same direction as u but with length norm(u) / r. By default, this is Divide, or (#1/#2)&.";

PrincipalAxes::usage = "PrincipalAxes[matrix] gives the principal axes matrix U such that U . Transpose[matrix] == Transpose@PrincipalComponents[matrix] (up to reflection).";
PrincipalAxes::moptx = "Method option `1` in PrincipalAxes is not one of {\"Covariance\", \"Correlation\"}.";

MeshRegionInterpolate::usage = "MeshRegionInterpolate[region, field, points] yields the result of interpolating the given field values across the nodes of the given mesh at the given point or points using an interpolation order of 1.";

AlignPoints3D::usage = "AlignPoints3D[a, b] yields a point-set with an identical distance matrix as the point-set b such that the distance between the corresponding points in point-set a has been minimized; effectively, this aligns the rows in the n x 3 matrix b with the rows in the n x 3 matrix b using rotation, translation, and reflection only.
AlignPoints3D[b -> a] is equivalent to AlignPoints3D[a, b].";

InsetAxis::usage = "InsetAxis[from, to] yields a list of graphics primitives that draws a floating axis between the given points from and to. The following options may be given:
  * Position (Automatic) may be Left, Right, Top, or Bottom, specifying that the axis is being drawn in the relevant location of the graphic. This affects the directions that the ticks point, the side that the tick labels appear on, and the side that the axis label appears on. If Automatic, will auto-detect the side based on the angle of the axis, assuming that it is either on the Left or Bottom of the plot.
  * DataRange (Automatic) specifies the distance covered by the axis; if {min, max} is given, then the axis assumes that between the from and to points the axis should be values that vary linearly from min to max.
  * Function (Identity) not yet supported.
  * BaseStyle (Automatic) style for text.
  * AxesStyle (Automatic) style for the axis line.
  * TicksStyle (Automatic) style for the tick lines.
  * TickLengths (Automatic) the length of the {major, minor} ticks; if Automatic, uses 0.015 and 0.01 times the length of the axis.
  * Ticks (Automatic) specifies which ticks should be drawn. This may be a list of {n, m} where n is the number of major ticks and m is the number of minor ticks between each pair of major ticks; alternately a list of explicit ticks may be given for n, and a list of values between 0 and 1 may be given for m.
  * TickSide (Automatic) specifies the side of the axis that the ticks should appear on; for a Left or Right positioned axis, 1 indicates the right and -1 indicates the left; for a Top or Bottom positioned axis, 1 indicates up and -1 indicates down.
  * LabelSide (Automatic) specifies the side of the axis that the tick labels should appear on.
  * LabelFunction (Automatic) specifies a function that is passed the value for each tick and which should return a form to render as the label for that tick; if None is returned, then nothing is rendered.
  * LabelAlignment (Automatic) specifies the alignment of the labels; this is {1,0} by default and is not rotated in any way.
  * LabelSpacing (Automatic) specifies the amount of space between the axis and the label; this is specified in terms of the ImageScaled units of each label.
  * LabelStyle (Automatic) specifies the style to be used (after BaseStyle) for the tick labels.
  * AxisLabelSide (Automatic) specifies the side of the axis that the axis label should appear on.
  * AxisLabel (None) specifies the label of the axis.
  * AxisLabelPosition (Automatic) specifies the position along the axis that the label should appear (by default, uses the middle of the axis).
  * AxisLabelAlignment (Automatic) specifies the axis label text direction; this vector is rotated with the axis, so a value of {1,0} will always be parallel the axis.
  * AxisLabelSpacing (Automatic) specifies the amount of space between the axis and the axis label in terms of the ImageScaled axis units.";
InsetAxis::badpos = "Position `1` not recognized (should be Top, Right, Bottom, Left, or Automatic)";

TickLengths::usage = "TickLengths is a keyword option for InsetAxis that specifies the lengths of the {major, minor} ticks.";
TickSide::usage = "TickSide is a keyword option for InsetAxis that specifies the side of the axis the ticks should appear on.";
LabelSide::usage = "LabelSide is a keyword option for InsetAxis that specifies the side of the axis that the tick labels should appear on.";
LabelFunction::usage = "LabelFunction is a keyword option for InsetAxis that specifies how a value along the axis should be converted into a tick label.";
LabelAlignment::usage = "LabelAlignment is a keyword option for InsetAxis that specifies the text direction for the tick labels.";
LabelSpacing::usage = "LabelSpacing is a keyword option for InsetAxis that specifies the spacing between the tick labels and the axis.";
AxisLabel::usage = "AxisLabel is a keyword option for InsetAxis that specifies the label that should be printed for the axis.";
AxisLabelPosition::usage = "AxisLabelPosition is a keyword option for InsetAxis that specifies the position, along the axis, that the axis label should be aligned with.";
AxisLabelSide::usage = "AxisLabelSide is a keyword option for InsetAxis that specifies the side of the axis that the axis label should appear on.";
AxisLabelAlignment::usage = "AxisLabelAlignment is a keyword option for InsetAxis that specifies the text direction of the axis label.";
AxisLabelSpacing::usage = "AxisLabelSpacing is a keyword option for InsetAxis that specifies the spacing between the axis and the axis label.";

Canvas::usage = "Canvas[] creates a new canvas object. The following options may be given:
  * Style may specify a Directive used for text in the canvas.
  * ImageSize may specify the size of the canvas in inches; by default, the canvas is 7 x 7 inches.
  * Background may specify the background color of the canvas; by default this is White.";
CanvasInset::usage = "CanvasInset[canvas, obj, args...] declares that Inset[obj, args...] should be included in the given canvas. Note that the coordinate system of a canvas is in inches starting from the lower left corner.";
CanvasGraphics::usage = "CanvasGraphics[canvas, graphics] declares that the given graphics should be included in the given canvas. Note that the coordinate system of a canvas is in inches starting from the lower left corner.";
CanvasText::usage = "CanvasText[canvas, text, args...] declares that Text[text, args...] should be included in the given canvas. Note that the coordinate system of a canvas is in inches starting from the lower left corner.";
$CanvasTop::usage = "$CanvasTop is the y coordinate of the top of the canvas.";
$CanvasBottom::usage = "$CanvasBottom is the y coordinate of the bottom of the canvas.";
$CanvasLeft::usage = "$CanvasLeft is the x coordinate of the left side of the canvas.";
$CanvasRight::usage = "$CanvasRight is the x coordinate of the right side of the canvas.";
$CanvasUR::usage = "$CanvasUR is the coordinates of the upper right corner of the canvas.";
$CanvasUL::usage = "$CanvasUL is the coordinates of the upper left corner of the canvas.";
$CanvasLR::usage = "$CanvasLR is the coordinates of the lower right corner of the canvas.";
$CanvasLL::usage = "$CanvasLL is the coordinates of the lower left corner of the canvas.";
$CanvasCenter::usage = "$CanvasCenter is the coordinate of the center of the canvas.";
$CanvasHeight::usage = "$CanvasHeight is the height of the canvas in inches.";
$CanvasWidth::usage = "$CanvasWidth is the width of the canvas in inches.";

Begin["`Private`"];

(* MissingQ, if we need to define it... *)
If[$VersionNumber < 10.2 && !ValueQ[MissingQ[Null]],
  (MissingQ[expr_] := (Head[expr] === Missing);
   Protect[MissingQ])];

(* #Quote *****************************************************************************************)
SetAttributes[Quote, HoldFirst];
Quote[expr_ /; 0 == Min[Last /@ Position[Hold[expr], Eval]]] := With[
  {held = Hold[expr]},
  With[
    {eidcs = First /@ Split[
       Sort@Position[held, Eval[_]],
       #1 == #2[[1 ;; Length[#1]]]&]},
    With[
      {evals = Extract[held, eidcs][[All, 1]]},
      Quote@@ReplaceAll[
        ReplacePart[held, Thread[eidcs -> evals]],
        Quote[x_] :> x]]]];

(* #HoldQ *****************************************************************************************)
SetAttributes[HoldQ, HoldFirst];
HoldQ[expr_] := Hold@@Quote[expr];
Protect[Quote, Eval, HoldQ];

(* #FailMessage ***********************************************************************************)
FailMessage[tag_String, tmpl_, args___] := (
  Message[tmpl, args];
  Failure[tag, <|"MessageTemplate" -> tmpl, "MessageParameters" -> {args}|>]);
Protect[FailMessage];

(* #FlipIntegerBytes ******************************************************************************)
(* This code was adapted (by Noah C. Benson, <nben@nyu.edu>) from a pull request given by 
   Szabolcs Horvát <szhorvat@gmail.com> in order to match the Neurotica library aesthetic *)
FlipIntegerBytes[i_Integer, byteCount_Integer /; 0 < byteCount] := If[2^(8*byteCount) <= i,
  Message[FlipIntegerBytes::badarg, "given integer is out of range for number of bytes"],
  FromDigits[Reverse@IntegerDigits[i, 256, byteCount], 256]];
FlipIntegerBytes[i_Integer, type_String] := Replace[
  type,
  {"Integer8"   :> FlipIntegerBytes[i, 1],
   "Integer16"  :> FlipIntegerBytes[i, 2],
   "Integer24"  :> FlipIntegerBytes[i, 3],
   "Integer32"  :> FlipIntegerBytes[i, 4],
   "Integer64"  :> FlipIntegerBytes[i, 8],
   "Integer128" :> FlipIntegerBytes[i, 16],
   _ :> Message[
     FlipIntegerBytes::badarg, 
     "type must be an integer or \"IntegerN\" where N is 8, 16, 32, ... 128."]}];
FlipIntegerBytes[i_Integer] := FlipIntegerBytes[i, 4];
Protect[FlipIntegerBytes];

(* #$CacheDirectory *******************************************************************************)
$CacheDirectory = FileNameJoin[{$UserBaseDirectory, "AutoCache"}];

(* #$AutoCreateCacheDirectory *********************************************************************)
$AutoCreateCacheDirectory = True;
$AutoCreateCacheDirectory /: Set[$AutoCreateCacheDirectory, b:(True|False)] := (
  Unprotect[$AutoCreateCacheDirectory];
  $AutoCreateCacheDirectory = b;
  Protect[$AutoCreateCacheDirectory];
  b);
Protect[$AutoCreateCacheDirectory];

(* #AutoCacheFilename *****************************************************************************)
Options[AutoCacheFilename] = {Directory -> Automatic, CreateDirectory -> Automatic};
AutoCacheFilename[name_String, OptionsPattern[]] := With[
  {splitName = FileNameSplit[name],
   canCreate = Replace[
       OptionValue[CreateDirectory],
       {Automatic :> $AutoCreateCacheDirectory,
        Except[True|False] :> (
          Message[AutoCache::badopt, "CreateDirectory must be True, False, or Automatic"];
          Throw[$Failed])}]},
  With[
    {dir = Replace[
       OptionValue[Directory],
       {Automatic :> Which[
          First[splitName] == "", FileNameJoin[Most[splitName]],
          First[splitName] == "~", FileNameJoin[Most[splitName]],
          $CacheDirectory === Temporary, ($CacheDirectory = CreateDirectory[]),
          True, FileNameJoin@Prepend[Most[splitName], $CacheDirectory]],
        Except[_String] :> (
          Message[AutoCache::badopt, "Directory must be Automatic or a string"];
          Throw[$Failed])}],
     file = StringReplace[Last[splitName], {s:(__ ~~ ".mx") :> s, s__ :> (s <> ".mx")}, 1]},
    Catch@FileNameJoin[
      {Which[
         DirectoryQ[dir], dir,
         canCreate, Replace[
           CreateDirectory[dir],
           $Failed :> (Message[AutoCache::nodir, dir]; Throw[$Failed])],
         True, (Message[AutoCache::nomkdir, dir]; Throw[$Failed])],
       file}]]];
Protect[AutoCacheFilename];

(* #$AutoCacheEvaluateQ ***************************************************************************)
$AutoCacheEvaluateQ = True;

(* #AutoCache *************************************************************************************)
Options[AutoCache] = {
  Quiet -> False,
  Check -> True,
  Directory -> Automatic,
  CreateDirectory -> Automatic};
Attributes[AutoCache] = {HoldRest};
AutoCache[name_String, body_, OptionsPattern[]] := Catch@With[
  {quiet = TrueQ[OptionValue[Quiet]],
   check = TrueQ[OptionValue[Check]],
   fileName = AutoCacheFilename[
     name,
     Directory -> OptionValue[Directory],
     CreateDirectory -> OptionValue[CreateDirectory]]},
  With[
    {cachedRes = If[StringQ[fileName] && FileExistsQ[fileName],
       Block[{Global`data = None}, Get[fileName]; Global`data],
       None]},
    With[
      {theRes = If[cachedRes === None || cachedRes === $Failed,
         Which[
           !TrueQ[$AutoCacheEvaluateQ], Throw[$Failed],
           check,                       Check[body, $Failed],
           True,                        body],
         cachedRes]},
      If[cachedRes === None || cachedRes == $Failed,
        Block[{Global`data = theRes}, If[theRes =!= $Failed, DumpSave[fileName, Global`data]]]];
      theRes]]];
Protect[AutoCache];

(* #AutoCachedQ ***********************************************************************************)
Options[AutoCachedQ] = {Directory -> Automatic};
AutoCachedQ[name_String, opts:OptionsPattern[]] := Quiet@Check[
  FileExistsQ@AutoCacheFilename[name, CreateDirectory -> False, opts],
  False];
Protect[AutoCachedQ];

(* #SetSafe ***************************************************************************************)
SetAttributes[SetSafe, HoldAll];
SetSafe[f_, expr_] := With[
  {res = Check[expr, $Failed]},
  If[res === $Failed, $Failed, Set[f, res]]];
Protect[SetSafe];

(* #Memoize ***************************************************************************************)
$MemoizePatternName = $MemoizePatternName;
Protect[$MemoizePatternName];
SetAttributes[Memoize, HoldAll];
Memoize[forms:(SetDelayed[_,_]..)] := CompoundExpression@@Replace[
  Hold[forms],
  HoldPattern[SetDelayed[f_, expr_]] :> ReplacePart[
    Hold[
      Evaluate[Pattern[Evaluate[$MemoizePatternName], f]],
      Evaluate[Hold[Evaluate[$MemoizePatternName], expr]]],
    {{2,0} -> Set, 0 -> SetDelayed}],
  {1}];
Protect[Memoize];

(* #MemoizeSafe ***********************************************************************************)
SetAttributes[MemoizeSafe, HoldAll];
MemoizeSafe[forms:(SetDelayed[_,_]..)] := CompoundExpression@@Replace[
  Hold[forms],
  HoldPattern[SetDelayed[f_, expr_]] :> ReplacePart[
    Hold[
      Evaluate[Pattern[Evaluate[$MemoizePatternName], f]],
      Evaluate[Hold[Evaluate[$MemoizePatternName], expr]]],
    {{2,0} -> SetSafe, 0 -> SetDelayed}],
  {1}];
Protect[MemoizeSafe];

(* #Forget ****************************************************************************************)
SetAttributes[Forget, HoldAll];
Forget[symbol_] := With[
  {sym1 = Unique[],
   sym2 = Unique[],
   down = DownValues[symbol]},
  With[
    {patterns = Cases[
       down,
       ReplacePart[
         Hold[
           Evaluate[
             Pattern @@ {
               sym1,
               Hold[
                 Evaluate[HoldPattern@@{Pattern[Evaluate[$MemoizePatternName], _]}],
                 Evaluate[Hold[Evaluate[$MemoizePatternName], _]]]}],
           Evaluate[Hold[Evaluate[{sym1}], Evaluate[{1,1} -> sym2]]]],
         {{1,2,2,0} -> (Set|SetSafe),
          {1,2,0} -> RuleDelayed,
          {2,1,0} -> First,
          {2,0} -> ReplacePart,
          0 -> RuleDelayed}],
       {1}]},
    With[
      {memoized = Cases[
         down[[All, 1]], 
         Evaluate[(Alternatives @@ patterns) :> Evaluate[Hold[Evaluate[sym2]]]],
         {2}]},
      Scan[Apply[Unset, #]&, memoized]]]];
Protect[Forget];      

(* #Indices ***************************************************************************************)
Indices[list_List, patt_] := Pick[Range[Length@list], list, patt];
Protect[Indices];

(* #TemporarySymbol *******************************************************************************)
TemporarySymbol[] := With[{sym = Unique[]}, SetAttributes[Evaluate[sym], Temporary]; sym];
TemporarySymbol[s_String] := With[{sym = Unique[s]}, SetAttributes[Evaluate[sym], Temporary]; sym];
Protect[TemporarySymbol];

(* #DefineImmutable *******************************************************************************)
SetAttributes[DefineImmutable, HoldAll];
Options[DefineImmutable] = {
  SetSafe -> True,
  Symbol -> Automatic};
DefineImmutable[RuleDelayed[pattern_, sym_Symbol], args_, OptionsPattern[]] := Check[
  Block[
    {sym},
    With[
      {instructions0 = If[#[[1,0]] === Hold, ReplacePart[#, {1,0} -> List], #]&@Hold[args],
       type = Unique@SymbolName@Head[pattern],
       box = Replace[
         OptionValue[Symbol],
         {Automatic :> Unique@ToString[sym],
          Except[_Symbol] :> Message[DefineImmutable::badarg, "Symbol option must be a symbol"]}],
       setFn = Replace[OptionValue[SetSafe], {True -> SetSafe, Except[True] -> Set}]},
      With[
        {instructions = Thread@Evaluate@NestWhile[#[[{1},2]]&, instructions0, #[[1,0]] === With&],
         outerWithPos = Last@NestWhile[
           {(#[[1]])[[{1}, 2]], Append[#[[2]], 2]}&,
           {instructions0, {}},
           (#[[1]])[[1, 0]] === With&]},
        With[
          {patterns = Apply[HoldPattern, #]& /@ instructions[[All, {1}, 1]],
           heads = Replace[
             instructions[[All, {1}, 0]],
             {Hold[Set] -> Set,
              Hold[Rule] -> Rule,
              Hold[RuleDelayed] -> RuleDelayed,
              Hold[SetDelayed] -> SetDelayed,
              x_ :> Message[
                DefineImmutable::badarg, 
                "Instructions bust be ->, =, :=, or :> forms: " <> ToString[x]]},
             {1}],
           bodies = instructions[[All, {1}, 2]]},
          If[Count[patterns, form_ /; form[[1,1]] === sym, {1}] < Length[patterns],
            Message[
              DefineImmutable::badarg, 
              "All field patterns must use the object as their first parameter"]];
          MapThread[
            Function[
              If[#1 =!= SetDelayed && #1 !MatchQ[Hold @@ #2, Hold[_[sym]]],
                Message[DefineImmutable::badarg, "rule and set functions must be unary"]]],
            {heads, patterns}];
          (* Setup the graph of dependencies *)
          With[
            {deps = Flatten@Last@Reap[
               (* We sort instructions into 4 groups:
                *   Init: instructions that must be calculated at startup (a -> b or a = b)
                *   Delay: instructions that needn't be calculated/saved (a := b)
                *   Settable: instructions that can be changed via Clone (a = b)
                *   Lazy: instructions that are delayed then memoized (a :> b)
                * We also collect Edges:
                *   An edge occurs when the RHS of an instruction references another instruction
                *)
               Sow[None, "Edge"];
               Sow[None, "Init"];
               Sow[None, "Delay"];
               Sow[None, "Settable"];
               Sow[None, "Lazy"];
               MapThread[
                 Function[{head, body, id},
                   If[head === SetDelayed,
                     Sow[id, "Delay"],
                     With[
                       {matches = Select[
                          Range[Length@patterns],
                          (heads[[#]] =!= SetDelayed && Count[body,patterns[[#]],Infinity] > 0)&]},
                       If[head =!= RuleDelayed, Sow[id, "Init"], Sow[id, "Lazy"]];
                       If[head === Set, Sow[id, "Settable"]];
                       Scan[
                         Function[
                           If[id == #,
                             Message[DefineImmutable::badarg, "Self-loop detected in dependencies"],
                             Sow[DirectedEdge[#, id], "Edge"]]],
                         matches]]]],
                 {heads, bodies, Range[Length@heads]}],
               {"Edge", "Init", "Delay", "Settable", "Lazy"},
               Rule[#1, Rest[#2]]&]},
            With[
              {delay = "Delay" /. deps,
               members = Complement[Range@Length[heads], "Delay" /. deps],
               init = "Init" /. deps,
               lazy = "Lazy" /. deps,
               lazyIdx = Part[
                 SortBy[
                   Join[
                     MapIndexed[#1 -> {2, #2[[1]]}&, "Lazy" /. deps],
                     MapIndexed[#1 -> {1, #2[[1]]}&, "Init" /. deps]],
                   First],
                 All, 2]},
              (* The easiest part to setup is the delayed items; do them now *)
              Do[
                TagSetDelayed @@ Join[
                  Hold[box],
                  ReplacePart[Hold @@ {patterns[[id]]}, {1,1,1} -> Pattern@@{sym, Blank[box]}],
                  bodies[[id]]],
                {id, "Delay" /. deps}];
              (* The direct accessors are also pretty easy to create... 
                 We create these slightly differently for lazy and non-lazy members. *)
              Do[
                TagSetDelayed @@ Join[
                  Hold[box],
                  ReplacePart[
                    Hold @@ {patterns[[members[[id]]]]}, 
                    {1,1,1} -> Pattern@@{sym, Blank[box]}],
                  ReplacePart[
                    (* For lazy: sym[[2, k]]; for init: sym[[1, k]] *)
                    Hold @@ {Hold[sym, Evaluate[lazyIdx[[id, 1]]], Evaluate[lazyIdx[[id, 2]]]]},
                    {1,0} -> Part]],
                {id, Range[Length@members]}];
              (* The constructor requires that we evaluate things in certain orders... 
                 we start by making some symols to use for each value *)
              With[
                {syms = Table[Unique[], {Length@members}],
                 (* We also make a graph of the dependencies *)
                 depGraph = With[
                   {tmp = Graph[members, "Edge" /. deps]},
                   If[!AcyclicGraphQ[tmp],
                     Message[DefineImmutable::badarg, "Cyclical dependency detected"],
                     tmp]]},
                (* with the transitive closure of the dependency graph, we know all the downstream
                   dependencies of any given element *)
                With[
                  {depStream = With[
                     {tc = TransitiveClosureGraph[depGraph]},
                     Map[
                       Function[
                         {EdgeList[tc, DirectedEdge[_,#]][[All, 1]],
                          EdgeList[tc, DirectedEdge[#,_]][[All, 2]]}],
                       members]],
                   (* Given the dependency graph, we can also determine the order non-delayed values
                      need to be evaluated in to prevent dependency errors *)
                   initOrder = Reverse@Part[
                     NestWhileList[
                       Function@With[
                         {goal = #[[1]], known = #[[3]]},
                         With[
                           {knowable = Select[
                              goal,
                              Function[
                                0 == Length@Complement[
                                  EdgeList[depGraph, DirectedEdge[_,#]][[All,1]], 
                                  known]]]},
                           {Complement[goal, knowable], knowable, Union[Join[known, knowable]]}]],
                       With[
                         {easy = Select[
                            "Init" /. deps,
                            EdgeCount[depGraph, DirectedEdge[_,#]] == 0&]},
                         {Complement["Init" /. deps, easy], easy, easy}],
                       Length[#[[1]]] > 0&],
                     All, 2]},
                  (* okay, now we build the constructor;
                     this is a big ugly code chunk due to the macro-nature of it... *)
                  SetDelayed @@ Join[
                    Hold[pattern],
                    Hold@@With[
                      {constructorBody = ReplaceAll[
                         (* To construct the body of the custructor:
                          * (1) make a core: a body that sets the lazy symbols and makes the form
                          * (2) wrap the core in layers of With[{init...}, core]
                          *)
                         Fold[
                           (* (2): wrap the core-so-far in the next outer layer of init vars *)
                           Function@ReplacePart[
                             Hold@Evaluate@Join[
                               Hold@Evaluate@Map[
                                 Join[Hold@@{syms[[#]]}, bodies[[members[[#]]]]]&,
                                 #2],
                               #1],
                             {{1,1,_,0} -> Set,
                              {1,0} -> With}],
                           (* (1): make a core that sets the lazy symbols and yields the form *)
                           With[
                             {idcs = Map[
                                Position[members,#][[1,1]]&,
                                Complement[members, Flatten[initOrder]]],
                              formSym = Unique[],
                              lazyRevIdx = (#[[All, All, 1]])&@Map[
                                  Rest@SortBy[#[[All, 2 ;; 3]], Last]&,
                                  SortBy[
                                    GatherBy[
                                      Join[
                                        MapIndexed[{#1[[1]], #2[[1]], #1[[2]]}&, lazyIdx],
                                        {{1, 0, 0}, {2, 0, 0}}],
                                      First],
                                    #[[1,1]]&]]},
                             ReplacePart[
                               Hold@Evaluate@Join[
                                 ReplacePart[
                                   Hold@Evaluate[Hold[#1,Unique[]]& /@ syms[[idcs]]],
                                   {1,_,0} -> Set],
                                 (* Here we make the actual form, prior to setting the symbols so
                                    that they are easier to hold: *)
                                 With[
                                   {form = Hold@Evaluate[
                                      box @@ ReplacePart[
                                        syms[[#]]& /@ lazyRevIdx,
                                        {2,0} -> Hold]]},
                                   ReplacePart[
                                     Hold@Evaluate@Join[
                                       ReplacePart[
                                         Hold @@ {{Flatten[Hold[Hold@Evaluate@formSym, form]]}},
                                         {1,1,0} -> Set],
                                       ReplacePart[
                                         Hold@Evaluate@Join[
                                           Flatten[
                                             Hold @@ MapThread[
                                               Function[
                                                 ReplacePart[
                                                   ReplaceAll[
                                                     Hold@Evaluate@Hold[
                                                       {#1}, 
                                                       Evaluate[Join[Hold[#1], #2]]],
                                                     {sym -> formSym}],
                                                   {{1,2,0} -> setFn,
                                                    {1,0} -> SetDelayed,
                                                    {1,1,0} -> Evaluate}]],
                                               {syms[[idcs]], bodies[[members[[idcs]]]]}]],
                                           Hold@Evaluate@formSym],
                                         {1,0} -> CompoundExpression]],
                                     {1,0} -> With]]],
                               {1,0} -> With]],
                           Map[Position[members, #][[1,1]]&, initOrder, {2}]],
                         MapThread[Rule, {patterns[[members]], syms}]]},
                      (* At this point, we need to return a Hold[] pattern, and constructorBody is
                         all that we really need; however, we may need to wrap some extra data
                         around our definitions... *)
                      If[outerWithPos == {}, 
                        constructorBody,
                        ReplacePart[
                          ReplacePart[instructions0, Prepend[outerWithPos, 1] -> constructorBody],
                          Join[{1}, outerWithPos, {0}] -> Identity]]]];
                  (* we also want to build a clone function *)
                  With[
                    {settables = "Settable" /. deps,
                     patternNames = #[[1,0]]& /@ patterns},
                    Evaluate[box] /: Clone[b_box, changes___Rule] := Check[
                      With[
                        {rules = {changes}},
                        Which[
                          (* No changes to be made; just return the current object *)
                          rules == {}, b,
                          (* multiple changes: do them one at a time *)
                          Length[rules] > 1, Fold[Clone, b, rules],
                          (* otherwise, we have one change; just handle it *)
                          True, With[
                            {id = Replace[
                               Select[
                                 Indices[patternNames, rules[[1,1]]],
                                 MemberQ[settables, #]&],
                               {{i_} :> i,
                                _ :> Message[
                                  Clone::badarg,
                                  "unrecognized or unsettable rule: " <> ToString[rules[[1,1]]]]}],
                             val = rules[[1,2]]},
                            (* Iterate through the values that depend on this one *)
                            With[
                              {harvest = Reap[
                                 Fold[
                                   Function@With[
                                     {bCur = #1, iids = #2},
                                     ReplacePart[
                                       bCur,
                                       Map[
                                         Function[
                                           lazyIdx[[ Position[members, #1][[1,1]] ]] -> If[
                                             heads[[#1]] === RuleDelayed,
                                             With[
                                               {tmp = TemporarySymbol[]},
                                               Sow[tmp -> bodies[[#1]]];
                                               tmp],
                                             ReleaseHold@ReplaceAll[
                                               bodies[[#1]],
                                               sym -> bCur]]],
                                         iids]]],
                                   ReplacePart[b, lazyIdx[[ Position[members, id][[1,1]] ]] -> val],
                                   Rest@First@Last@Reap[
                                     NestWhile[
                                       Function[{G},
                                         With[
                                           {vs = Select[VertexList[G], VertexInDegree[G,#] == 0&]},
                                           Sow[vs];
                                           VertexDelete[G, vs]]],
                                       Subgraph[
                                         depGraph,
                                         VertexOutComponent[depGraph, id, Infinity]],
                                       VertexCount[#] > 0&]]]]},
                              (* harvest[[1]] is the new box'ed object; we need to setup the 
                                 temporary symbols, though. *)
                              With[
                                {finalSym = Unique[]},
                                Scan[
                                  Function@With[
                                    {memSym = #[[1]], memBody = #[[2]]},
                                    ReplacePart[
                                      {memSym, Join[
                                         Hold@Evaluate@memSym,
                                         ReplaceAll[memBody, sym -> finalSym]]},
                                      {{2,0} -> Set,
                                       0 -> SetDelayed}]],
                                  Flatten[harvest[[2]]]];
                                Set @@ Join[Hold[Evaluate@finalSym], Hold[harvest][[{1},1]]];
                                finalSym]]]]],
                      $Failed]];
                SetAttributes[Evaluate[box], Protected];
                True]]]]]]]],
  $Failed];
Protect[DefineImmutable];

(* #AutoManageData ********************************************************************************)
$AutoMemoizeAfter = 0;
$AutoCacheAfter = 1.0;

DeHoldPattern[expr:Hold[y_[x___]]] := If[y === HoldPattern, DeHoldPattern@Hold[x], expr];
(* Helper function; takes Hold[patt, form] and yeilds parsed-patt :> parsed-replacement *)
PrepareDatumAutoManager[dat_, amt_, act_, cacheDir_] := With[
  {patt = Unique["pattern"],
   lhs = DeHoldPattern[dat[[{1}, 1]]]},
  With[
    {rule = ReleaseHold[RuleDelayed @@@ ReplacePart[dat, {1,1} -> (patt:HoldPattern@@lhs)]]},
    Replace[
      rule,
      (p_ :> rhs_) :> (
         p :> Catch@With[
           {hash = Hash@HoldPattern[patt],
            head = HoldPattern[patt][[1,0]]},
           With[
             {acname = "AutoManagedCache_" <> ToString[head] <> "_" <> ToString[hash]},
             (* Check the existing auto-cache first... *)
             With[
               {ac = AutoCache[acname, $Failed, Directory -> cacheDir]},
               If[ac =!= $Failed, (patt = ac; Throw[ac])]];
             (* Okay, we have to calculate it *)
             With[
               {calc = Check[AbsoluteTiming[rhs], $Failed]},
               (* Check for failure... *)
               If[calc === $Failed, Throw[calc]];
               (* See if we want to memoize it first... *)
               If[calc[[1]] >= amt, patt = calc[[2]]];
               (* Then see if we want to cache it... *)
               If[calc[[1]] >= act, AutoCache[acname, calc[[2]], Directory -> cacheDir]];
               (* Then we return it! *)
               calc[[2]]]]])]]];

Options[AutoManageData] = {
  AutoCacheAfter :> $AutoCacheAfter,
  AutoMemoizeAfter :> $AutoMemoizeAfter,
  Directory -> Automatic};
SetAttributes[AutoManageData, HoldAll];
AutoManageData[data__SetDelayed, OptionsPattern[]] := With[
  {amt = OptionValue[AutoMemoizeAfter],
   act = OptionValue[AutoCacheAfter],
   cacheDir = OptionValue[Directory]},
  With[
    {defs = SetDelayed@@@Hold@@Map[
       PrepareDatumAutoManager[#, amt, act, cacheDir]&,
       Apply[List, Hold /@ Hold[data]]]},
    Block@@Join[
      Hold[{$AutoMemoizeAfter = amt, $AutoCacheAfter = act}],
      defs]]];

Protect[AutoManageData, PrepareDatumAutoManager,
        $AutoMemoizeAfter, $AutoCacheAfter, AutoMemoizeAfter, AutoCacheAfter];

(* #Let *******************************************************************************************)
SetAttributes[Let, HoldAll];
With[
  {tagCompoundExpr = Unique["ComplexExpression"],
   tagWith = Unique["With"]},
  Let[
    {variables:((_Symbol|((Set|SetDelayed|Rule|RuleDelayed)[_,_]))...)},
    body_
   ] := ReplaceRepeated[
    Fold[
     Function@Replace[
       #2,
       {Hold[s_Symbol] :> Hold[
          tagWith,
          {Set[s, Unique@ToString[s]]},
          SetAttributes[s, Temporary],
          #1],
        Hold[Rule[s_Symbol, expr_]] :> Hold[tagWith, {Set[s, expr]}, #1],
        Hold[Set[s_Symbol, expr_]] :> Hold[
          tagWith,
          {Set[s, Unique@ToString[s]]},
          SetAttributes[s, Temporary],
          s = expr,
          #1],
        Hold[RuleDelayed[s_Symbol, expr_]] :> Hold[
          tagWith,
          {Set[s, Unique@ToString[s]]},
          SetAttributes[s, Temporary],
          SetDelayed[s, Set[s, expr]],
          #1],
        Hold[SetDelayed[s_Symbol, expr_]] :> Hold[
          tagWith,
          {Set[s, Unique@ToString[s]]},
          SetAttributes[s, Temporary],
          SetDelayed[s, expr],
          #1],
        Hold[Rule[s_Symbol[args___], expr_]] :> Hold[
          tagWith,
          {Set[s, Unique@ToString@s]},
          Set[s[args], expr],
          SetAttributes[s, {Temporary, Protected}],
          #1],
        Hold[Set[s_Symbol[args___], expr_]] :> Hold[
          tagWith,
          {Set[s, Unique@ToString@Head[s]]},
          SetAttributes[s, Temporary],
          s[args] = expr,
          #1],
        Hold[RuleDelayed[s_Symbol[args___], expr_]] :> With[
          {pattSym = Unique["patt"]},
          Hold[
           tagWith,
           {Set[s, Unique@ToString[s]]},
           SetAttributes[s, Temporary],
           SetDelayed[pattSym : s[args], Set[pattSym, expr]],
           #1]],
        Hold[SetDelayed[s_Symbol[args___], expr_]] :> Hold[
          tagWith,
          {Set[s, Unique@ToString[s]]},
          SetAttributes[s, Temporary],
          SetDelayed[s[args], expr],
          #1]}],
     Hold[tagCompoundExpr, body],
     Hold /@ Reverse@Hold[variables]],
    {Hold[tagCompoundExpr, b__] :> CompoundExpression[b],
     Hold[tagWith, v_, b_] :> With[v, b],
     Hold[tagWith, v_, b_, bs__] :> With[v, CompoundExpression[b, bs]]}]];
SyntaxInformation[Let] = {"ArgumentsPattern" -> {{__},_}};
Protect[Let];

(* #NormalizeRows *********************************************************************************)
NormalizeRows[X_] := With[
  {tr = Transpose[X]},
  Transpose[tr / Table[#, {Length[tr]}]&@Sqrt@Total[tr^2]]];
NormalizeRows[{}] = {};
Protect[NormalizeRows];

(* #NormalizeColumns ******************************************************************************)
NormalizeColumns[X_] := X / ConstantArray[# + (1 - Unitize[#]), {Length[X]}]&@Sqrt@Total[X^2];
NormalizeColumns[{}] = {};
Protect[NormalizeColumns];

(* #RowNorms **************************************************************************************)
RowNorms[X_] := Norm /@ X;
RowNorms[{}] = {};
Protect[RowNorms];

(* #ColumnNorms ***********************************************************************************)
ColumnNorms[Xt_] := Sqrt @ Total[Xt^2];
ColumnNorms[{}] = {};
Protect[ColumnNorms];

(* #QuaternionToRotationMatrix *******************************************************************)
QuaternionToRotationMatrix[{a_, b_, c_, d_}] := {
  {a^2 + b^2 - c^2 - d^2, 2*b*c - 2*a*d, 2*b*d + 2*a*c},
  {2*b*c + 2*a*d, a^2 + c^2 - b^2 - d^2,   2*c*d - 2*a*b},
  {2*b*d - 2*a*c, 2*c*d + 2*a*b, a^2 + d^2 - c^2 - b^2}};
QuaternionToRotationMatrix[{b_, c_, d_}] := QuaternionToRotationMatrix[
  {Sqrt[1.0 - (b^2 + c^2 + d^2)], b, c, d}];
Protect[QuaternionToRotationMatrix];

(* #BinaryStringFix *******************************************************************************)
BinaryStringFix[clist:{_String..}] := StringJoin[TakeWhile[clist, ToCharacterCode[#] != {0}&]];
BinaryStringFix[clist:{_Integer..}] := FromCharacterCode @ TakeWhile[clist, # != 0&];
Protect[BinaryStringFix];

(* #ReadBinaryStructure ***************************************************************************)
$ReadBinaryStructureInstructionKey = {
  type_String :> Function[BinaryRead[#, type]],
  {type_String} :> Function[BinaryReadList[#, type, 1]],
  {type_String, n_Integer} :> Function[BinaryReadList[#, type, n]],
  {type_String, n_Integer, f_} :> Function[f[BinaryReadList[#, type, n]]],
  l_List :> With[
    {els = Replace[l, $ReadBinaryStructureInstructionKey, 1]},
    Function[With[{stream = #}, #[stream]& /@ els]]],
  Rule[name_, instr_] :> With[
    {r = (instr /. $ReadBinaryStructureInstructionKey)}, 
    Function[name -> r[#]]],
  q_ :> Message[ReadBinaryStructure::badinstr, ToString[q]]};
Protect[$ReadBinaryStructureInstructionKey];
  
ReadBinaryStructure[stream_, instructions_List] := Check[
  With[
    {instFns = Replace[instructions, $ReadBinaryStructureInstructionKey, {1}]},
    Map[
      #[stream]&,
      instFns]],
  $Failed];
Protect[ReadBinaryStructure];

(* #NeuroticaPermanentDatum ***********************************************************************)
$NeuroticaPermanentDataPath = FileNameJoin[{$UserBaseDirectory, ".NeuroticaPermanentData.dat"}];
$NeuroticaPermanentData = If[FileExistsQ[$NeuroticaPermanentDataPath],
  Association @ Map[
    Function[#[[1]] -> StringJoin[Riffle[Rest[#], "\t"]]],
    Import[$NeuroticaPermanentDataPath, "Table"]],
  Association[]];
Protect[$NeuroticaPermamentDataPath, $NeuroticaPermamentData];

NeuroticaPermanentDataSave[] := Check[
  (If[Length[$NeuroticaPermanentData] == 0,
     If[FileExistsQ[$NeuroticaPermanentDataPath], DeleteFile[$NeuroticaPermanentDataPath]],
     Export[
       $NeuroticaPermanentDataPath,
       Map[(List @@ #)&, Normal[$NeuroticaPermanentData]],
       "Table"]];
   True),
  False];
Protect[NeuroticaPermanentDataSave];

NeuroticaPermanentDatum[name_String, value_String] := With[
  {cur = Lookup[$NeuroticaPermanentData, name]},
  Unprotect[$NeuroticaPermanentData];
  $NeuroticaPermanentData[name] = value;
  Protect[$NeuroticaPermanentData];
  NeuroticaPermanentDataSave[]];
NeuroticaPermanentDatum[name_String, None] := With[
  {cur = Lookup[$NeuroticaPermanentData, name]},
  Unprotect[$NeuroticaPermanentData];
  KeyDropFrom[$NeuroticaPermanentData, name];
  Protect[$NeuroticaPermanentData];
  NeuroticaPermanentDataSave[]];
NeuroticaPermanentDatum[name_String] := Replace[
  $NeuroticaPermanentData[name],
  Missing[___] -> None];
Protect[NeuroticaPermanentDatum];


(* #Unboole ***************************************************************************************)
With[
  {FT = {False,True}},
  Unboole[x_Real] := FT[[Unitize[x] + 1]];
  Unboole[x_Integer] := FT[[Unitize[x] + 1]];
  Unboole[x_?NumericQ] := FT[[Unitize[x] + 1]];
  Unboole[x_] := Piecewise[{{False, x == 0}}, True];
  Unboole[x_List /; ArrayQ[x, 1, NumericQ]] := FT[[Unitize[x] + 1]];
  Unboole[x_List] := Map[Unboole, x]];
Protect[Unboole];

(* #MapNamed **************************************************************************************)
MapNamed[f_, args:{Rule[_,_List]..}, level_:1] := With[
  {names = args[[All, 1]]},
  MapThread[
    Function[f@Association@Thread[names -> {##}]],
    args[[All,2]],
    level]];
MapNamed[f_, Rule[name_, list_List], level_:{1}] := Map[
  Function[f[<|name -> #|>]],
  list,
  level];
Protect[MapNamed];

(* #DivideCheck ***********************************************************************************)
DivideCheck[a_, b_, c_:0] := With[
  {bne0 = Unitize@Chop[b]},
  With[
    {beq0 = 1 - unit},
    c * beq0 + bneq0 * a / (b + beq0)]];
SetAttributes[DivideCheck, NumericFunction];
Protect[DivideCheck];

(* #IndexList *************************************************************************************)
IndexList[data_List] := Association@Last@Reap[
  MapThread[Sow, {Range@Length[data], data}],
  _,
  Rule];
Protect[IndexList];

(* #Iterate ***************************************************************************************)
Attributes[Iterate] = {HoldAll};

ReifyIterator[mx_] := ReifyIterator[1, mx, 1];
ReifyIterator[mn_, mx_] := ReifyIterator[mn, mx, 1];
ReifyIterator[mn_, mx_, sp_] := With[
  {els = Floor[(mx - mn)/sp + 1]},
  {mn, mx, sp, els, mn + els*sp}];
ReifyMatchingIterator[iter0_] := {iter0[[1]], iter0[[3]]};
ReifyMatchingIterator[iter0_, mx_] := {1, (mx - 1)/(iter0[[4]] - 1)};
ReifyMatchingIterator[iter0_, mn_, mx_] := {mn, (mx - mn)/(iter0[[4]] - 1)};

Iterate[body_, iter1_List, iters__List] := Iterate[Iterate[body, iters], iter1];
Iterate[body_, iter:{Except[_List], Repeated[_, {1, 3}]}] := Table[body, iter];
Iterate[body_, {iter:{Except[_List], Repeated[_, {1, 3}]}}] := Table[body, iter];
Iterate[body_] := body;
Iterate[
  body_,
  {i0:{s0:Except[_List], sp0:Repeated[_, {1, 3}]},
   {s1:Except[_List], sp1:Repeated[_, {0, 2}]},
   is:{Except[_List], Repeated[_, {0, 2}]} ...}
  ] := With[
    {sym = Unique[],
     pat = HoldPattern[s1],
     dat0 = ReifyIterator[sp0]},
    With[
      {dat1 = ReifyMatchingIterator[dat0, sp1]},
      With[
        {mn0 = dat0[[1]], mx0 = dat0[[5]], md0 = dat0[[3]],
         mn1 = dat1[[1]], md1 = dat1[[2]]},
        With[
          {bodyfix = Join[
             Hold[{sym = mn1 + md1*((s0 - mn0)/md0)}],
             Hold[body] /. s1 -> sym]},
          Iterate@@ReplacePart[
            Hold[bodyfix, {i0, is}],
            {1, 0} -> With]]]]];
Protect[Iterate, ReifyIterator, ReifyMatchingIterator];

(* #FlatOuter *************************************************************************************)
FlatOuter[args__] := With[
  {listArgs = TakeWhile[Rest[{args}], ListQ]},
  Flatten[Outer[args], Length[listArgs] - 2]];
Protect[FlatOuter];

(* #FlatTable *************************************************************************************)
FlatTable[args__] := Flatten[
  Table[args],
  Length@Hold[args] - 2];
SetAttributes[FlatTable, HoldAll];
SyntaxInformation[FlatTable] = SyntaxInformation[Table];
Protect[FlatTable];

(* #FlatIterator **********************************************************************************)
FlatIterator[args__] := Flatten[
  Iterate[args],
  Length@Hold[args] - 2];
SetAttributes[FlatIterate, HoldAll];
Protect[FlatIterate];

(* #WithOptions ***********************************************************************************)
Attributes[WithOptions] = {HoldFirst};
WithOptions[f_[args___]] := f[args];
WithOptions[f_[args___], opts_List] := With[
  {head = f},
  head[args, Sequence@@FilterRules[opts, Options[head]]]];
WithOptions[f_[args___], opt1:Except[_List], opts___] := WithOptions[f[args], {opt1, opts}];
Protect[WithOptions];

(* #UpdateOptions *********************************************************************************)
UpdateOptions[opts:{(Rule|RuleDelayed)[_,_]...}] := opts;
UpdateOptions[opts:{(Rule|RuleDelayed)[_,_]...}, {}] := opts;
UpdateOptions[opts:{(Rule|RuleDelayed)[_,_]...}, repl:(Rule|RuleDelayed)[name_,_]] := Prepend[
  DeleteCases[opts, (Rule|RuleDelayed)[name, _], {1}],
  repl];
UpdateOptions[opts:{(Rule|RuleDelayed)[_,_]...}, repl:{(Rule|RuleDelayed)[_,_]..}] := With[
  {onames = opts[[All, 1]],
   rnames = repl[[All, 1]]},
  Table[
    SelectFirst[If[MemberQ[rnames, name], repl, opts], #[[1]] === name &],
    {name, Union[rnames, onames]}]];
Protect[UpdateOptions];

(* #RenderMovie ***********************************************************************************)
Attributes[RenderMovie] = {HoldAll};
Options[RenderMovie] = Join[
  {Format -> Image,
   Frames -> Automatic,
   FrameRate -> Automatic,
   Duration -> Automatic,
   Restricted -> False,
   ImageResolution -> 200},
  FilterRules[Options[Image], Except[ImageResolution]]];
ParseMovieFrames[n_Integer?Positive, fr:(_?NumericQ)?Positive, dur:(_?NumericQ)?Positive] := With[
  {nn = Floor[dur*fr]},
  If[nn == n,
    {n, fr, dur},
    Message[
      RenderMovie::badarg,
      "Frames, FrameRate, and Duration must have incompatible arguments; "
        <> "try setting one to Automatic"]]];
ParseMovieFrames[n_Integer?Positive, fr:(_?NumericQ)?Positive, Automatic] := {n, fr, fr*n};
ParseMovieFrames[n_Integer?Positive, Automatic, dur:(_?NumericQ)?Positive] := {n, n/dur, dur};
ParseMovieFrames[Automatic, f:(_?NumericQ)?Positive, d:(_?NumericQ)?Positive] := {f*d, f, d};
ParseMovieFrames[Automatic, Automatic, d:(_?NumericQ)?Positive] := ParseMovieFrames[
  Automatic, 20, d];
ParseMovieFrames[Automatic, fr:(_?NumericQ)?Positive, Automatic] := ParseMovieFrames[
  Automatic, fr, 6];
ParseMovieFrames[Automatic, Automatic, Automatic] := {120, 20, 6};
ParseMovieFrames[args__] := Message[
   RenderMovie::badarg,
   "FrameRate, Frames, and Duration must be a valid combination of "
     <> "positive numbers and Automatic values: " <> ToString[{args}]];
RenderMovie[body0_, iter_, opts:OptionsPattern[]] := With[
  {frameDat = ParseMovieFrames[OptionValue[Frames], OptionValue[FrameRate], OptionValue[Duration]],
   fmt = Replace[
     OptionValue[Format],
     {Image -> Image,
      Graphics -> Graphics,
      _ :> Message[RenderMovie::badarg, "Format must be Image or Graphics"]}],
   imgOpts = Sequence@@FilterRules[{opts}, Options[Image]]},
  With[
    {body = If[fmt =!= Image,
       Hold[body0],
       With[
         {sym = Unique[]},
         ReplacePart[
           Hold@Evaluate@Hold[
             {sym = body0},
             Image[sym, imgOpts]],
           {1,0} -> With]]]},
    Block[
      {$FrameNumber, $ElapsedTime},
      Iterate @@ Join[
        body,
        ReplacePart[
          Hold@Evaluate@List[
            Evaluate@Hold[$FrameNumber, 1, Evaluate[frameDat[[1]]], 1],
            Evaluate@Hold[$ElapsedTime, 0, Evaluate[frameDat[[3]]]],
            Hold@@iter],
          {1,_,0} -> List]]]]];
Protect[RenderMovie, ParseMovieFrames];

(* #StatusReport **********************************************************************************)
Attributes[StatusReport] = {HoldAll};
Options[StatusReport] = Options[Row];
StatusReport[body_, opts:OptionsPattern[]] := Null;

(* #GaussianInterpolation *************************************************************************)
$GaussianInterpolationDefaultNormFunction = Norm;
$GaussianInterpolationDefaultDifferenceFunction = Function[#2 - #1];
$GaussianInterpolationDefaultScaleFunction = Divide;
$GaussianInterpolationDefaultDistanceFunction = EuclideanDistance;
Options[GaussianInterpolation] = Join[
  {StandardDeviation -> Automatic,
   Threshold -> Automatic,
   MetaInformation -> {},
   NormFunction -> Automatic,
   VectorScaleFunction -> Automatic,
   VectorDifferenceFunction -> Automatic,
   Weights -> None},
  FilterRules[
    Options[Nearest],
    Except[DistanceFunction]]];
(* how to call an interpolation function directly... *)
(G_GaussianInterpolationFunction)[x_] := GaussianInterpolationLookup[G, x];
(* And how to get the gradient... *)
GaussianInterpolationFunction /: Grad[
  G_GaussianInterpolationFunction, 
  x_] := GaussianInterpolationDerivative[G, x];
(* how to chance the array for the data *)
GaussianInterpolation[G_GaussianInterpolationFunction, (Rule|RuleDelayed)[Array, x_]] := Clone[
  G,
  Array -> x];
GaussianInterpolation[G_GaussianInterpolationFunction, {(Rule|RuleDelayed)[Array, x_]}] := Clone[
  G,
  Array -> x];
(* alternate constructor... *)
GaussianInterpolation[sample:{{_List, _}..}, opts:OptionsPattern[]] := GaussianInterpolation[
   Transpose[Append @@ Transpose[sample]],
   opts];
(* now, define the immutable... *)
DefineImmutable[
  GaussianInterpolation[sampleData_?ArrayQ, optionsArg:OptionsPattern[]] :> G,
  {(* The sample data... *)
   Array[G] = sampleData,
   Keys[G] -> With[
     {dat = Array[G]},
     Which[
       VectorQ[dat, NumericQ], List /@ Range@Length[dat],
       MatrixQ[dat, NumericQ], If[
         Last@Dimensions[dat] == 1,
         List /@ Range@Length[dat],
         dat[[All, 1 ;; -2]]],
       True, Message[
         GaussianInterpolation::badarg,
         "Sample data must be a 1D or 2D numeric array"]]],
   Values[G] -> With[
     {dat = Array[G]},
     Which[
       VectorQ[dat, NumericQ], dat,
       MatrixQ[dat, NumericQ], If[
         Last@Dimensions[dat] == 1, 
         Flatten[dat],
         dat[[All, -1]]],
       True, Message[
         GaussianInterpolation::badarg,
         "Sample data must be a 1D or 2D numeric array"]]],
   Dimensions[G] -> Length@First@Keys[G],

   (* The options... *)
   PrivateOptions[G] = UpdateOptions[Options[GaussianInterpolation], {optionsArg}],
   Options[G] -> With[
     {po = PrivateOptions[G],
      X = Keys[G],
      possibleOpts = Union @ Part[Options[GaussianInterpolation], All, 1]},
     If[Or[Union@Join[Head /@ po, {Rule, RuleDelayed}] =!= {Rule, RuleDelayed},
           Length[possibleOpts] != Length @ Union[possibleOpts, po[[All, 1]]]],
       Message[
         GaussianInterpolation::badarg,
         "Unrecognized options given to GaussianInterpolation"],
       With[
         {scale = Replace[
            StandardDeviation /. po,
            {Automatic :> With[
               {dat = Keys[G]},
               0.125 * If[VectorQ[dat],
                 StandardDeviation[dat],
                 Mean[StandardDeviation /@ Transpose[dat]]]],
             s_?NumericQ /; s > 0 :> s,
             _ :> Message[
               GaussianInterpolation::badarg,
               "StandardDeviation must be Automatic or a positive real number"]}],
          meta = MetaInformation /. po,
          normFn = Replace[
            OptionValue[NormFunction],
            Automatic -> $GaussianInterpolationDefaultNormFunction],
          scaleFn = Replace[
            OptionValue[VectorScaleFunction],
            Automatic -> $GaussianInterpolationDefaultScaleFunction],
          diffFn = Replace[
            OptionValue[VectorDifferenceFunction],
            Automatic -> $GaussianInterpolationDefaultDifferenceFunction],
          ws = Replace[
            OptionValue[Weights],
            Automatic -> None]},
         With[
           {threshold = Replace[
              Threshold /. po,
              {Automatic -> {Min[{Length[X], 10}], 3.5*scale},
               {n_Integer /; n > 0} :> {n, Infinity},
               c_?NumericQ /; c >0 :> {Min[{Length[X], 10}], c},
               {n_Integer, c_?NumericQ} /; n > 0 && c > 0 :> {n, c},
               _ :> Message[
                 GaussianInterpolation::badarg,
                 "Threshold must be a list containing a positive integer or a positive cutoff"]}]},
           Join[
             {StandardDeviation -> scale,
              Threshold -> threshold,
              MetaInformation -> meta,
              NormFunction -> normFn,
              VectorScaleFunction -> scaleFn,
              VectorDifferenceFunction -> diffFn,
              Weights -> ws},
             DeleteCases[
               FilterRules[po, Options[Nearest]],
               (Rule|RuleDelayed)[DistanceFunction, _],
               {1}]]]]]],
   Options[G, arg_List] := With[
     {opts = Options[G]},
     First@Last@Reap[
       Scan[
         Function@With[
           {val = opts[#]},
           If[Head[val] === Missing,
             Message[Options::optnf, #, GaussianInterpolation],
             Sow[# -> val]]],
         arg]]],
   Options[G, arg:Except[_List]] := Options[G, {arg}],
   SetOptions[G, arg_List] := Clone[G, PrivateOptions -> UpdateOptions[PrivateOptions[G], arg]],
   SetOptions[G, arg_Rule] := Clone[G, PrivateOptions -> UpdateOptions[PrivateOptions[G], arg]],
   SetOptions[G, arg_RuleDelayed] := Clone[G, PrivateOptions -> UpdateOptions[PrivateOptions[G], arg]],

   (* Metadata for calculation... *)
   DistanceFunction[G] -> With[
     {normFn = NormFunction /. Options[G],
      diffFn = VectorDifferenceFunction /. Options[G]},
     If[And[normFn === $GaussianInterpolationDefaultNormFunction,
            diffFn === $GaussianInterpolationDefaultDifferenceFunction],
       $GaussianInterpolationDefaultDistanceFunction,
       Composition[normFn, diffFn]]],
   Nearest[G] :> With[
     {X = Keys[G],
      nearestOpts = FilterRules[Options[G], Options[Nearest]],
      distFn = DistanceFunction[G]},
     Nearest[
       X -> Automatic,
       DistanceFunction -> If[distFn === $GaussianInterpolationDefaultDistanceFunction,
         Automatic,
         distFn],
       Sequence @@ nearestOpts]],
   GaussianFilter[G] -> NormalDistribution[0, StandardDeviation /. Options[G]],
   GaussianWeightsDerivative[G] -> With[
     {distribution = GaussianFilter[G]},
     Block[
       {x},
       Function@@ReplaceAll[
         Hold@@{D[PDF[distribution, x[1]], x[1]]},
         x -> Slot]]],
   Weights[G] -> With[
     {ws = Weights /. Options[G],
      n = Length@Array[G]},
     Which[
       NumericQ[ws] || ws === None,  ConstantArray[1.0, n],
       ListQ[ws] && Length[ws] == n, ws,
       True,                         Message[Options::optnf, Weights, GaussianInterpolation]]],

   (* The actual lookup calculation... *)
   GaussianInterpolationLookup[G, xs_ /; MatrixQ[xs, NumericQ]] := With[
     {dims = Dimensions[G],
      near = Nearest[G],
      thold = Threshold /. Options[G],
      distribution = GaussianFilter[G],
      distFn = DistanceFunction[G],
      ws = Weights[G],
      X = Keys[G],
      Y = Values[G]},
     Which[
       dims === Length@First[xs], With[
         {idcs = If[thold[[2]] === Infinity,
            near[xs, thold[[1]]],
            MapThread[Union, {near[xs, thold[[1]]], near[xs, {Infinity, thold[[2]]}]}]]},
         With[
           {weights = (ws[[#]]&/@idcs) * PDF[
              distribution,
              MapThread[
                MapThread[distFn, {#1, #2}]&,
                {MapThread[ConstantArray, {xs, Length /@ idcs}],
                 X[[#]]& /@ idcs}]]},
           MapThread[
             Function[Dot[Y[[#1]], #2] / Total[#2]],
             {idcs, weights}]]],
       dims === Length[xs], GaussianInterpolationLookup[G, Transpose[xs]],
       True, Message[GaussianInterpolation::xdims]]],
   GaussianInterpolationLookup[G, xs_ /; VectorQ[xs, NumericQ]] := If[Dimensions[G] == 1,
     GaussianInterpolationLookup[G, Transpose[{xs}]][[All, 1]],
     First@GaussianInterpolationLookup[G, {xs}]],
   GaussianInterpolationLookup[G, x_?NumericQ] := First@GaussianInterpolationLookup[G, {{x}}],
   (* And the derivative... *)
   GaussianInterpolationDerivative[G, xs_ /; MatrixQ[xs, NumericQ]] := With[
     {dims = Dimensions[G],
      near = Nearest[G],
      thold = Threshold /. Options[G],
      distribution = GaussianFilter[G],
      distFn = DistanceFunction[G],
      normFn = NormFunction /. Options[G],
      diffFn = VectorDifferenceFunction /. Options[G],
      scaleFn = VectorScaleFunction /. Options[G],
      ws = Weights[G],
      X = Keys[G],
      Y = Values[G]},
     Which[
       dims === Length@First[xs], With[
         {idcs = If[thold[[2]] === Infinity,
            near[xs, thold[[1]]],
            MapThread[Union, {near[xs, thold[[1]]], near[xs, {Infinity, thold[[2]]}]}]],
          dwdr = GaussianWeightsDerivative[G]},
         With[
           {diffs = MapThread[
              diffFn,
              {X[[#]]& /@ idcs, 
               MapThread[ConstantArray, {xs, Length /@ idcs}]}]},
           With[
             {norms = Map[normFn, diffs, {2}]},
             With[
               {normeds = MapThread[scaleFn, {diffs, norms}, 2],
                weights = (ws[[#]]&/@idcs) * PDF[distribution, norms],
                ys = Y[[#]]& /@ idcs},
               With[
                 {numer = Total /@ (weights * ys),
                  dweightsdr = normeds * dwdr[norms],
                  denom = 1.0 / (Total /@ weights)},
                 With[
                   {ddenomdr = -denom^2 * Total /@ dweightsdr,
                    dnumerdr = Total /@ (dweightsdr * ys)},
                   numer * ddenomdr + dnumerdr * denom]]]]]],
       dims === Length[xs], Lookup[G, Transpose[xs]],
       True, Message[GaussianInterpolation::xdims]]],
   GaussianInterpolationDerivative[G, x_ /; VectorQ[x, NumericQ]] := If[Dimensions[G] == 1,
     GaussianInterpolationDerivative[G, Transpose[{x}]][[All, 1]],
     First@GaussianInterpolationDerivative[G, {x}]],
   GaussianInterpolationDerivative[G, x_?NumericQ] := First@GaussianInterpolationDerivative[
     G, {{x}}]},
  SetSafe -> True,
  Symbol -> GaussianInterpolationFunction];
(* How to print one of these... *)
MakeBoxes[gi_GaussianInterpolationFunction, form_] := MakeBoxes[#, form]&[
  With[
    {style = {
       FontSize -> 11,
       FontColor -> Gray,
       FontFamily -> "Arial",
       FontWeight -> "Thin"}},
    Row[
      {"GaussianInterpolation"[
         Panel[
           Grid[
             MapThread[
               Function[
                 {Spacer[4], Style[#1, Sequence @@ style],
                  Spacer[2], #2, Spacer[4]}],
               {{"Data Points:", "Dimensionality:", "Standard Deviation:"},
                {Length@Array[gi], Dimensions[gi], StandardDeviation /. Options[gi]}}],
             Alignment -> Table[{Right, Right, Center, Left, Left}, {3}]]]]},
      BaseStyle -> Darker[Gray]]]];
Protect[VectorScaleFunction, VectorDifferenceFunction];

(* #PrincipalAxes *********************************************************************************)
Options[PrincipalAxes] = {Method -> "Covariance"};
PrincipalAxes[mtx_?MatrixQ, OptionsPattern[]] := Catch@With[
  {cofn = Replace[
     OptionValue[Method],
     {"Covariance" -> Covariance,
      "Correlation" -> Correlation,
      a_ :> (Message[PrincipalAxes::moptx, a]; Throw[$Failed])}]},
  Eigenvectors@Covariance[mtx - ConstantArray[Mean[mtx], Length[mtx]]]];
Protect[PrincipalAxes];

(* #MeshRegionInterpolate *************************************************************************)
Options[MeshRegionInterpolate] = {Chop -> 10^-4};
MeshRegionInterpolate[reg_, field_, pts0_, OptionsPattern[]] := With[
  {faces = Transpose[MeshCells[reg, 2][[All,1]]],
   X = Transpose@MeshCoordinates[reg],
   chop = OptionValue[Chop],
   pts = RegionNearest[reg, pts0]},
  With[
    {cells = Region`Mesh`MeshMemberCellIndex[reg, pts][[All, 2]],
     void = Unitize@Chop[RowNorms[pts0-pts], chop]},
    With[
      {ff = faces[[All, cells + void]]},
      With[
        {fx   = X[[All,#]]& /@ ff,
         vals = field[[#]]& /@ ff},
        With[
          {vtcs = MapThread[List, {Transpose[{pts,pts,pts}, {1,3,2}], RotateLeft[fx], fx}]},
          With[
            {s2 = Transpose@Table[Total /@ ((RotateLeft[v] - v)^2), {v, vtcs}]},
            With[
              {areas = With[
                 {tmp = 4.0*s2[[1]]*s2[[2]] - (s2[[1]] + s2[[2]] - s2[[3]])^2},
                 0.25 * Sqrt[tmp + tmp*Clip[tmp, {0,0}, {-1,0}]]]},
              With[
                {w = RotateRight[vals]*areas,
                 tot = Total[areas]},
                Plus[
                  Total[w]/(tot + (1 - Unitize[tot])),
                  Replace[Unitize[void + (1 - Unitize[tot])], 1 -> Indeterminate, {1}]]]]]]]]]];
Protect[MeshRegionInterpolate];

(* #AlignPoints3D *********************************************************************************)
AlignPoints3D[source_ /; MatrixQ[source, NumericQ],
              target_ /; MatrixQ[target, NumericQ]
              ] /; (
                Dimensions[target] == Dimensions[source] && Length@First[target] == 3
              ) := With[
  {mtar = N[Transpose[target] - Mean[target]],
   msrc = N[Transpose[source] - Mean[source]]},
  With[
    {d = mtar - msrc, s = mtar + msrc},
    With[
      {q = {{Total@Total[d^2],
             0, 0, 0},
            {Total[s[[2]]*d[[3]] - s[[3]]*d[[2]]],
             Total[s[[2]]^2 + s[[3]]^2 + d[[1]]^2],
             0, 0},
            {Total[d[[1]]*s[[3]] - s[[1]]*d[[3]]],
             Total[d[[1]]*d[[2]] - s[[1]]*s[[2]]],
             Total[s[[1]]^2 + s[[3]]^2 + d[[2]]^2],
             0},
            {Total[s[[1]]*d[[2]] - d[[1]]*s[[2]]],
             Total[d[[1]]*d[[3]] - s[[1]]*s[[3]]],
             Total[d[[2]]*d[[3]] - s[[2]]*s[[3]]],
             Total[s[[1]]^2 + s[[2]]^2 + d[[3]]^2]}}},
      With[
        {v = #2[[First@Ordering[#1]]] & @@ Eigensystem[q]},
        Transpose[
          Mean[source] + Dot[
            {{v[[1]]^2 + v[[2]]^2 - v[[3]]^2 - v[[4]]^2,
              2*(v[[2]]*v[[3]] - v[[1]]*v[[4]]),
              2*(v[[2]]*v[[4]] + v[[1]]*v[[3]])},
             {2*(v[[2]]*v[[3]] + v[[1]]*v[[4]]),
              v[[1]]^2 + v[[3]]^2 - v[[2]]^2 - v[[4]]^2,
              2*(v[[3]]*v[[4]] - v[[1]]*v[[2]])},
             {2*(v[[2]]*v[[4]] - v[[1]]*v[[3]]),
              2*(v[[3]]*v[[4]] + v[[1]]*v[[2]]),
              v[[1]]^2 + v[[4]]^2 - v[[2]]^2 - v[[3]]^2}},
            mtar]]]]]];
Protect[AlignPoints3D];

(* #InsetAxis *************************************************************************************)
ClearAll["Neurotica`Util`InsetAxis`*"];
Options[InsetAxis] = {
  Position -> Automatic,
  DataRange -> Automatic,
  Function -> Identity,
  BaseStyle -> Automatic,
  AxesStyle -> Automatic,
  TicksStyle -> Automatic,
  TickLengths -> Automatic,
  Ticks -> Automatic,
  TickSide -> Automatic,
  LabelSide -> Automatic,
  LabelFunction -> Automatic,
  LabelAlignment -> Automatic,
  LabelSpacing -> Automatic,
  LabelStyle -> Automatic,
  AxisLabelSide -> Automatic,
  AxisLabel -> None,
  AxisLabelPosition -> Automatic,
  AxisLabelAlignment -> Automatic,
  AxisLabelSpacing -> Automatic};
InsetAxis`imscaled[dir_, mag_] := ImageScaled[{0.5, 0.5} + mag*0.5*dir];
InsetAxis`metaData[{from_, to_}, opts : OptionsPattern[InsetAxis]] := First@Last@Reap[
  With[
    {u0 = Normalize[to - from],
     spec = Replace[
       OptionValue[Ticks],
       {Automatic -> {Automatic, Automatic},
        None -> {None, None},
        k_Integer :> {k, Automatic},
        l_List /; Length[l] != 2 :> {l, Automatic}}],
     range = Replace[
       OptionValue[DataRange],
       {x_?NumericQ :> {0, x},
        Automatic :> Which[
          from[[1]] == to[[1]], {from[[2]], to[[2]]},
          from[[2]] == to[[2]], {from[[1]], to[[1]]},
          True, {0, Norm[to - from]}]}],
     lblfn = Replace[OptionValue[LabelFunction], Automatic -> TraditionalForm]},
    With[
      {dlen = range[[2]] - range[[1]],
       plen = Norm[from - to],
       pos = Replace[OptionValue[Position], Automatic :> If[u0[[1]]^2 >= 0.5, Bottom, Left]]},
      With[
        {tickLens = Replace[
           OptionValue[TickLengths],
           {Automatic :> plen*{0.015, 0.01},
            x:Except[_List] :> {x, 2/3*x},
            {x_} :> {x[[1]], 2/3*x}}],
         ticks = {
           Replace[
             spec[[1]],
             {None -> {},
              k_Integer :> Map[(range.{1 - #, #}) &, Range[0, 1, 1/k]],
              Automatic :> Select[FindDivisions[range, 8], range[[1]] <= # <= range[[2]] &]}],
           Replace[
             spec[[2]],
             {None -> {},
              k_Integer :> Most@Rest@Range[0, 1, 1/(k + 1)],
              Automatic :> {0.5}}]},
         tickSide = Replace[OptionValue[TickSide], Automatic -> 1],
         txtSide =
         Replace[OptionValue[AxisLabelSide], Automatic -> -1],
         lblSide = Replace[OptionValue[LabelSide], Automatic -> -1],
         uv = Which[
           pos === Top, With[
             {u = If[u0[[1]] < 0, -u0, u0]},
             {u, {u[[2]], -u[[1]]}}],
           pos === Bottom, With[
             {u = If[u0[[1]] < 0, -u0, u0]},
             {u, {-u[[2]], u[[1]]}}],
           pos === Left, With[
             {u = If[u0[[2]] < 0, -u0, u0]},
             {u, {u[[2]], -u[[1]]}}],
           pos === Right, With[
             {u = If[u0[[2]] < 0, -u0, u0]},
             {u, {-u[[2]], u[[1]]}}],
           True, Message[InsetAxis::badpos, pos]]},
        Sow["DataRange" -> range];
        Sow["DataLength" -> dlen];
        Sow["PlotLength" -> plen];
        Sow["Position" -> pos];
        Sow["AxisDirection" -> uv[[1]]];
        Sow["AxisNormal" -> uv[[2]]];
        Sow["AxesStyle" -> Replace[
          OptionValue[AxesStyle],
          {Automatic -> {Black, Dashing[{}], Thickness[Small]},
           x:Except[_List] :> {x}}]];
        Sow["TicksStyle" -> Replace[
          OptionValue[TicksStyle],
          {Automatic -> {Black, Dashing[{}], Thickness[Small]},
           x:Except[_List] :> {x}}]];
        Sow["BaseStyle" -> Replace[
          OptionValue[BaseStyle],
          Automatic -> Directive[FontFamily -> "Helvetica Neue",
                                 FontColor -> Black,
                                 FontWeight -> "Light"]]];
        Sow["AxisLabel" -> OptionValue[AxisLabel]];
        Sow["AxisLabelPosition" -> Replace[
          OptionValue[AxisLabelPosition],
          Automatic :> 0.5*(range[[2]] + range[[1]])]];
        Sow["AxisLabelAlignment" -> Replace[
          OptionValue[AxisLabelAlignment],
          Automatic -> {1, 0}]];
        Sow["LabelFunction" -> lblfn];
        Sow[
          "LabelAlignment" ->
          Replace[OptionValue[LabelAlignment], Automatic -> {1, 0}]];
        Sow["LabelStyle" -> Replace[
          OptionValue[LabelStyle],
          Automatic -> Directive[FontFamily -> "Helvetica Neue",
                                 FontWeight -> "Thin",
                                 FontColor -> Black]]];
        Sow["AxisLabelSpacing" -> Replace[
          OptionValue[AxisLabelSpacing],
          Automatic :> Plus[
            If[tickSide == txtSide, 0.75, 0],
            If[lblSide == txtSide, 2.5, 0],
            1]]];
        Sow["LabelSpacing" -> Replace[
          OptionValue[LabelSpacing],
          Automatic :> If[tickSide == lblSide, 1.0, 0.5]]];
        Sow["Function" -> Replace[OptionValue[Function], Automatic -> Identity]];
        Sow["TickSide" -> tickSide];
        Sow["LabelSide" -> lblSide];
        Sow["AxisLabelSide" -> txtSide];
        Sow["Ticks" -> ticks];
        Sow["MajorTickLength" -> tickLens[[1]]];
        Sow["MinorTickLength" -> tickLens[[1]]];
        With[
          {ticksMaj = Map[
             Function@Association@With[
               {crd = ((from*(1 - #) + to*#) &[(# - range[[1]])/(range[[2]] - range[[1]])])},
               {"Position" -> #, "Label" -> lblfn[#],
                "Start" -> crd, "End" -> (crd + tickSide*uv[[2]]*tickLens[[1]])}],
             ticks[[1]]]},
          Sow["MajorTicks" -> ticksMaj];
          Sow["MinorTicks" -> With[
            {dt = ticksMaj[[2]]["Position"] - ticksMaj[[1]]["Position"],
             dx = ticksMaj[[2]]["Start"] - ticksMaj[[1]]["Start"]},
            Join@@Map[
              Function@With[
                {x0 = dx*#, t0 = dt*#},
                Table[
                  With[
                    {x = x0 + maj["Start"], p = t0 + maj["Position"]},
                    <|"Start" -> x,
                      "End" -> (x + tickSide*uv[[2]]*tickLens[[2]]),
                      "Position" -> p|>],
                  {maj, Most[ticksMaj]}]],
              ticks[[2]]]]]];
        Sow["EndPoints" -> {from, to}]]]],
  _,
  Association@*First];
InsetAxis`drawAxis = Function@Append[#AxesStyle, Line[#EndPoints]];
InsetAxis`drawTicks = Function@List[
  (* Major Ticks... *)
  If[#MajorTicks === None,
    Nothing,
    Join[#AxesStyle, #TicksStyle, Line[{#Start, #End}] & /@ #MajorTicks]],
  (* Minor Ticks... *)
  If[#MinorTicks === None,
    Nothing,
    Join[#AxesStyle, #TicksStyle, Line[{#Start, #End}] & /@ #MinorTicks]]];
InsetAxis`drawTickLabels = Function@With[
  {lblPos = InsetAxis`imscaled[-#LabelSide*#AxisNormal, 1 + #LabelSpacing],
   sty = Join[#BaseStyle, #LabelStyle],
   lblAlign = #LabelAlignment},
  Map[
    Function@If[#Label === None,
      Nothing,
      Text[#Label, #Start, lblPos, lblAlign, BaseStyle -> sty]],
    #MajorTicks]];
InsetAxis`drawAxisLabel = Function@With[
  {rot = RotationMatrix[ArcTan @@ #AxisDirection],
   mn = #DataRange[[1]], mx = #DataRange[[2]],
   from = #EndPoints[[1]], to = #EndPoints[[2]]},
  Text[
    #AxisLabel,
    (from*(1 - #) + #*to) &[(#AxisLabelPosition - mn)/(mx - mn)],
    InsetAxis`imscaled[-Inverse[rot].(#AxisLabelSide*#AxisNormal), 1 + #AxisLabelSpacing],
    rot . #AxisLabelAlignment,
    BaseStyle -> #BaseStyle]];
InsetAxis[{from:{_, _}, to:{_, _}}, opts:OptionsPattern[]] := With[
  {meta = InsetAxis`metaData[{from, to}, opts]},
  {(* Axis Line *)
   InsetAxis`drawAxis[meta],
   (* The Ticks *)
   InsetAxis`drawTicks[meta],
   (* The Tick Labels *)
   InsetAxis`drawTickLabels[meta],
   InsetAxis`drawAxisLabel[meta]}];

Protect[InsetAxis, TickLengths, TickSide, LabelSide, LabelSpacing,
        AxisLabelSpacing, LabelFunction, LabelAlignment, AxisLabel,
        AxisLabelPosition, AxisLabelSide, AxisLabelAlignment];

(* #Canvas ****************************************************************************************)
SetAttributes[CanvasInset, HoldRest];
SetAttributes[CanvasGraphics, HoldRest];
SetAttributes[CanvasText, HoldRest];
Options[Canvas] = {
  Style -> Directive[FontFamily -> "Helvetica Neue",
                     FontColor -> Black,
                     FontWeight -> "Thin",
                     FontSize -> 10],
  ImageSize -> {7, 7},
  Background -> White};
Canvas[opts:OptionsPattern[]] := With[
  {sym = Unique["canvas"],
   fullOpts = Table[o -> OptionValue[o], {o, Options[Canvas][[All, 1]]}],
   isz = Replace[
     OptionValue[ImageSize],
     {{w_?NumericQ, h_?NumericQ} :> {0, w, 0, h},
      {{w0_?NumericQ, h0_?NumericQ}, {w_?NumericQ, h_?NumericQ}} :> {w0, w, h0, h},
      {w0_?NumericQ, h0_?NumericQ, w_?NumericQ, h_?NumericQ} :> {w0, w, h0, h},
      _ :> Message[General::optx, ImageSize, Canvas]}]},
  With[
    {CanvasDimBlock = Function[Null,
       Block[
         {$CanvasLeft = isz[[1]], $CanvasRight = isz[[2]],
          $CanvasTop = isz[[4]], $CanvasBottom = isz[[3]],
          $CanvasUR = isz[[{2, 4}]], $CanvasUL = isz[[{1, 4}]],
          $CanvasLR = isz[[{2, 3}]], $CanvasLL = isz[[{1, 4}]],
          $CanvasCenter = {Mean@isz[[{1, 2}]], Mean@isz[[{3, 4}]]},
          $CanvasWidth = isz[[2]] - isz[[1]],
          $CanvasHeight = isz[[4]] - isz[[3]]},
         ##],
       {HoldAll}]},
    sym /: Options[sym] = fullOpts;
    sym /: CanvasInsetList[sym] = {};
    sym /: CanvasInset[sym, code__] := CanvasDimBlock@With[
      {sty = Style /. Options[sym]},
      sym /: CanvasInsetList[sym] = Append[
        CanvasInsetList[sym],
        Hold@Inset[code, FormatType -> TraditionalForm, BaseStyle -> sty]];
      sym];
    sym /: CanvasGraphics[sym, code_] := CanvasDimBlock[
      sym /: CanvasInsetList[sym] = Append[
        CanvasInsetList[sym],
        Hold[code]];
      sym];
    sym /: CanvasText[sym, code__] := CanvasDimBlock@With[
      {sty = Style /. Options[sym]},
      sym /: CanvasInsetList[sym] = Append[
        CanvasInsetList[sym],
        Hold@Text[code, FormatType -> TraditionalForm, BaseStyle -> sty]];
      sym];
    sym /: Show[sym, showOpts : OptionsPattern[Graphics]] :=
    CanvasDimBlock@Catch@Block[
      {$CanvasQuality = False},
      With[
        {imsz = ImageSize /. Options[sym],
         bg = Background /. Options[sym],
         sty = Style /. Options[sym]},
        sym /: Show[sym, showOpts] = Check[
          WithOptions[
            Graphics@List[
              {FaceForm[bg], EdgeForm[None],
               Rectangle[{0, 0}, imsz]},
              ReleaseHold /@ CanvasInsetList[sym]],
            showOpts,
            BaseStyle -> sty,
            ImageSize -> imsz*72,
            PlotRange -> {{0, imsz[[1]]}, {0, imsz[[2]]}}],
          Throw[$Failed]]]];
    sym /: Graphics[sym, showOpts : OptionsPattern[Graphics]] :=
    CanvasDimBlock@Catch@Block[
      {$CanvasQuality = True},
      With[
        {imsz = ImageSize /. Options[sym],
         bg = Background /. Options[sym],
         sty = Style /. Options[sym]},
        sym /: Show[sym, showOpts] = Check[
          WithOptions[
            Graphics@List[
              {FaceForm[bg], EdgeForm[None],
               Rectangle[{0, 0}, imsz]},
              ReleaseHold /@ CanvasInsetList[sym]],
            showOpts,
            BaseStyle -> sty,
            ImageSize -> imsz*72,
            PlotRange -> {{0, imsz[[1]]}, {0, imsz[[2]]}}],
          Throw[$Failed]]]];
    sym]];
Protect[Canvas, CanvasInset, CanvasText, CanvasInsetList];

End[];
EndPackage[];

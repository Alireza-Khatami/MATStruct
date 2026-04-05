# MAT Struct File Format

This document describes the output file format produced by `VolumeVoronoiGPU` for the Medial Axis Transform (MAT) structural decomposition. This is intended to help understand and parse the output for downstream use.

---

## What is the MAT Structure?

The Medial Axis Transform (MAT) of a 3D shape is a skeleton-like representation — a set of medial spheres, edges, and faces that captures the shape's topology and geometry. The struct file classifies every element of this MAT mesh into one of four semantic types:

| Type ID | Name | Description |
|---|---|---|
| `0` | **SHEET** | A smooth region of the MAT interior, represented as a group of MAT faces |
| `1` | **SEAM** | A crease line where two sheets meet, represented as a group of MAT edges |
| `2` | **BOUNDARY** | A boundary curve at the periphery of the MAT, represented as a group of MAT edges |
| `3` | **JUNCTION** | A point where 3 or more sheets meet, represented as a group of MAT vertices (spheres) |

---

## File Format

The file is plain text. It is appended to the `.ma` file after the geometry (vertices, edges, faces).

### Top-Level Structure

```
<num_structures>
<structure_block_0>
<structure_block_1>
...
<structure_block_N-1>
```

### Each Structure Block

```
<struct_id> <type_id> <element_count>
<element_id_0> <element_id_1> ... <element_id_N>
```

- `struct_id` — zero-based integer ID of this structure
- `type_id` — integer (0=SHEET, 1=SEAM, 2=BOUNDARY, 3=JUNCTION)
- `element_count` — number of element IDs on the next line
- `element_ids` — space-separated list of indices into the MAT mesh:
  - For SHEET: indices into the **face** array of the MAT mesh
  - For SEAM / BOUNDARY: indices into the **edge** array of the MAT mesh
  - For JUNCTION: indices into the **vertex/sphere** array of the MAT mesh

---

## Example

```
15
0 1 147
3 7 10 15 27 ...
1 1 118
1108 1110 ...
8 0 412
0 1 2 9 10 ...
```

Interpretation:
- `15` — this MAT has 15 structural components
- `0 1 147` — structure 0, type SEAM, contains 147 MAT edge IDs
- `1 1 118` — structure 1, type SEAM, contains 118 MAT edge IDs
- `8 0 412` — structure 8, type SHEET, contains 412 MAT face IDs

---

## Relationship to the `.ma` File

The `.ma` file stores the full MAT mesh geometry followed by the struct data:

1. **Vertices** — MAT sphere centers and radii `(x, y, z, r)`
2. **Edges** — pairs of vertex indices
3. **Faces** — triples of vertex indices
4. **Struct** — the structural classification described in this document

The element IDs in the struct blocks are **0-based indices** into the corresponding geometry arrays above.

---

## Structural Types in Detail

### SHEET (type 0)
A sheet is a 2D region of the MAT corresponding to one smooth patch of the medial surface. It groups together MAT triangle faces that belong to the same local sheet. Each face in a sheet lies between two nearby parallel surface regions of the original shape.

### SEAM (type 1)
A seam is a 1D curve where exactly two sheets meet at a sharp angle. It groups together MAT edges along this crease. Seams correspond to sharp features (concave edges) on the original shape.

### BOUNDARY (type 2)
A boundary is a 1D curve at the periphery of the MAT where a sheet ends without meeting another sheet. It groups together MAT edges along the boundary. Boundaries typically correspond to flat or convex regions on the original shape.

### JUNCTION (type 3)
A junction is a 0D point where three or more sheets meet. It groups together MAT vertices (medial spheres) at these high-valence meeting points. Junctions correspond to complex regions such as corners or vertices on the original shape.

---

## Typical Output Statistics

For a typical mesh:
- Multiple **SHEETs** covering the bulk of the MAT faces (usually the largest structures)
- A few **SEAMs** along concave feature edges
- Several **BOUNDARies** along the periphery
- Rarely any **JUNCTIONs** (only for highly complex shapes)

---

## Source Code Reference

- Struct written by: `export_struct_only()` in `src/io_wrapper.cpp`
- Struct data lives in: `MedialMesh::mstructure` (vector of `MedialStructure`)
- Structure type enum: `MedialType` in `extern/libmat` (`SHEET=0, SEAM=1, BOUNDARY=2, JUNCTION=3`)
- Full MAT mesh class: `MedialMesh` in `extern/libmat/src/matbase/`

The Graphical Fragment Assembly (GFA)
described under https://github.com/pmelsted/GFA-spec/blob/master/GFA-spec.md
is a proposed format which allows
to describe the product of sequence assembly and is implemented in the
RGFA class defined in the rgfa gem. This gem represents an extension of the
RGFA class, which implements a binary format, BFA, equivalent to RGFA.

## Installation

Please install RGFA prior to this.
https://github.com/ggonnella/RGFA

## Specification

The BFA format is described here:
https://github.com/ggonnella/bfa/tree/master/specification/specification.pdf

## Poster

A conference poster describing RGFA and BFA has been presented at the
Genome Informatics 2016 conference.
The poster can be downloaded here:
https://github.com/ggonnella/bfa/tree/master/poster/poster.pdf

## Usage

require "rgfa" from the RGFA library and "bfa" from this library.

### GFA to BFA

To encode a GFA file into BFA, load it using g = RGFA.from_file(gfa_filename),
then write it to a BFA file using BFA::Writer.encode(bfa_filename, g).

### BFA to GFA

To decode a BFA file, use b = BFA::Reader.parse(bfa_filename). This will
create a RGFA object, which you can write to GFA using b.to_file(gfa_filename).


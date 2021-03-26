#!/usr/bin/env python
import os

for fileName in os.listdir("."):
	os.rename(fileName, fileName[:12] + ".pdf")

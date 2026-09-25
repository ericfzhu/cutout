# Third-party software

Cutout bundles BiRefNet-matting by Peng Zheng and collaborators, pinned to
`eccde0a8cbdce7ac5fecfeb06340fe7b949e85d9` from
https://huggingface.co/ZhengPeng7/BiRefNet-matting.
Code and weights are distributed under the MIT license.
Original implementation: https://github.com/ZhengPeng7/BiRefNet.
The upstream license is included in `Runtime/model/LICENSE`.

Cutout also bundles standard BiRefNet segmentation weights from
https://huggingface.co/ZhengPeng7/BiRefNet, pinned to
`e2bf8e4460fc8fa32bba5ea4d94b3233d367b0e4` (MIT license).
They use the same bundled BiRefNet architecture and license above.

The standalone CPython distribution is from python-build-standalone, installed
through uv. Its licenses are retained within the bundled Python runtime.
https://github.com/astral-sh/python-build-standalone

Python dependencies and their exact versions are recorded in
`Runtime/requirements.lock` in the source project. Their license files and
package metadata are retained in `Runtime/site-packages` in the application.
These include PyTorch and torchvision (BSD-style), Transformers (Apache 2.0),
timm (Apache 2.0), Kornia (Apache 2.0), einops (MIT), NumPy (BSD), Pillow
(MIT-CMU), and safetensors (Apache 2.0).

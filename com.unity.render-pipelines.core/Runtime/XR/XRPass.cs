using System;
using System.Collections.Generic;

namespace UnityEngine.Rendering
{
    internal struct XRPassCreateInfo
    {
        public RenderTargetIdentifier renderTarget;
        public RenderTextureDescriptor renderTargetDesc;
        public ScriptableCullingParameters cullingParameters;
        public Material occlusionMeshMaterial;
        public int multipassId;
        public int cullingPassId;
        public bool copyDepth;
    }

    /// <summary>
    /// XRPass holds the render target information and a list of XRView.
    /// XRView contains the parameters required to render (projection and view matrices, viewport, etc)
    /// When a pass has 2 views or more, single-pass will be active if the platform supports it.
    /// To avoid allocating every frame, XRView is a struct and XRPass is pooled.
    /// </summary>
    public class XRPass
    {
        readonly List<XRView> m_Views;
        readonly XROcclusionMesh m_OcclusionMesh;

        /// <summary>
        /// Parameterless constructor.
        /// Note: in order to avoid GC, the render pipeline should use XRPass.Create instead of this method.
        /// </summary>
        public XRPass()
        {
            m_Views = new List<XRView>(2);
            m_OcclusionMesh = new XROcclusionMesh(this);
        }

        /// <summary>
        /// Returns true if the pass contains at least one view.
        /// </summary>
        public bool enabled
        {
        #if ENABLE_VR && ENABLE_XR_MODULE
            get => viewCount > 0;
        #else
            get => false;
        #endif
        }

        /// <summary>
        /// If true, the render pipeline is expected to output a valid depth buffer to the renderTarget.
        /// </summary>
        public bool copyDepth { get; private set; }

        /// <summary>
        /// Index of the pass inside the frame.
        /// </summary>
        public int multipassId { get; private set; }

        /// <summary>
        /// Index used for culling. It can be shared between multiple passes.
        /// </summary>
        public int cullingPassId { get; private set; }

        /// <summary>
        /// Destination render target.
        /// </summary>
        public RenderTargetIdentifier renderTarget { get; private set; }

        /// <summary>
        /// Destination render target descriptor.
        /// </summary>
        public RenderTextureDescriptor renderTargetDesc { get; private set; }

        /// <summary>
        /// Parameters used for culling.
        /// </summary>
        public ScriptableCullingParameters cullingParams { get; private set; }

        /// <summary>
        /// Returns the number of views inside this pass.
        /// </summary>
        public int viewCount { get => m_Views.Count; }

        /// <summary>
        /// If true, the render pipeline is expected to use single-pass techniques to save CPU time.
        /// </summary>
        public bool singlePassEnabled { get => viewCount > 1; }

        /// <summary>
        /// Returns the projection matrix for a given view.
        /// </summary>
        /// <param name="viewIndex"></param>
        public Matrix4x4 GetProjMatrix(int viewIndex = 0)
        {
            return m_Views[viewIndex].projMatrix;
        }

        /// <summary>
        /// Returns the view matrix for a given view.
        /// </summary>
        /// <param name="viewIndex"></param>
        public Matrix4x4 GetViewMatrix(int viewIndex = 0)
        {
            return m_Views[viewIndex].viewMatrix;
        }

        /// <summary>
        /// Returns the viewport for a given view.
        /// </summary>
        /// <param name="viewIndex"></param>
        public Rect GetViewport(int viewIndex = 0)
        {
            return m_Views[viewIndex].viewport;
        }

        /// <summary>
        /// Returns the occlusion mesh for a given view.
        /// </summary>
        /// <param name="viewIndex"></param>
        public Mesh GetOcclusionMesh(int viewIndex = 0)
        {
            return m_Views[viewIndex].occlusionMesh;
        }

        /// <summary>
        /// Returns the destination slice index (for texture array) for a given view.
        /// </summary>
        /// <param name="viewIndex"></param>
        public int GetTextureArraySlice(int viewIndex = 0)
        {
            return m_Views[viewIndex].textureArraySlice;
        }

        /// <summary>
        /// Queue up render commands to enable single-pass techniques.
        /// Note: depending on the platform and settings, either single-pass instancing or the multiview extension will be used.
        /// </summary>
        /// <param name="cmd"></param>
        public void StartSinglePass(CommandBuffer cmd)
        {
            if (enabled)
            {
                if (singlePassEnabled)
                {
                    if (viewCount <= TextureXR.slices)
                    {
                        if (SystemInfo.supportsMultiview)
                        {
                            cmd.EnableShaderKeyword("STEREO_MULTIVIEW_ON");
                        }
                        else
                        {
                            cmd.EnableShaderKeyword("STEREO_INSTANCING_ON");
                            cmd.SetInstanceMultiplier((uint)viewCount);
                        }
                    }
                    else
                    {
                        throw new NotImplementedException($"Invalid XR setup for single-pass, trying to render too many views! Max supported: {TextureXR.slices}");
                    }
                }
            }
        }

        /// <summary>
        /// Queue up render commands to disable single-pass techniques.
        /// </summary>
        /// <param name="cmd"></param>
        public void StopSinglePass(CommandBuffer cmd)
        {
            if (enabled)
            {
                if (singlePassEnabled)
                {
                    if (SystemInfo.supportsMultiview)
                    {
                        cmd.DisableShaderKeyword("STEREO_MULTIVIEW_ON");
                    }
                    else
                    {
                        cmd.DisableShaderKeyword("STEREO_INSTANCING_ON");
                        cmd.SetInstanceMultiplier(1);
                    }
                }
            }
        }

        /// <summary>
        /// Returns true if the pass was setup with expected mesh and material.
        /// </summary>
        public bool hasValidOcclusionMesh { get => m_OcclusionMesh.hasValidOcclusionMesh; }

        /// <summary>
        /// Generate commands to render the occlusion mesh for this pass.
        /// In single-pass mode : the meshes for all views are combined into one mesh,
        /// where the corresponding view index is encoded into each vertex. The keyword
        /// "XR_OCCLUSION_MESH_COMBINED" is also enabled when rendering the combined mesh.
        /// </summary>
        /// <param name="cmd"></param>
        public void RenderOcclusionMesh(CommandBuffer cmd)
        {
            m_OcclusionMesh.RenderOcclusionMesh(cmd);
        }

        /// <summary>
        /// If true, late latching mechanism is available for the frame.
        /// </summary>
        public bool isLateLatchEnabled { get; internal set; }

        /// <summary>
        /// Used by the render pipeline to control the granularity of late latching.
        /// </summary>
        public bool canMarkLateLatch { get; set; }

        /// <summary>
        /// Track the state of the late latching system.
        /// </summary>
        internal bool hasMarkedLateLatch { get; set; }

        internal void AssignView(int viewId, XRView xrView)
        {
            if (viewId < 0 || viewId >= m_Views.Count)
                throw new ArgumentOutOfRangeException(nameof(viewId));

            m_Views[viewId] = xrView;
        }

        internal void AssignCullingParams(int cullingPassId, ScriptableCullingParameters cullingParams)
        {
            // Disable legacy stereo culling path
            cullingParams.cullingOptions &= ~CullingOptions.Stereo;

            this.cullingPassId = cullingPassId;
            this.cullingParams = cullingParams;
        }

        internal void UpdateCombinedOcclusionMesh()
        {
            m_OcclusionMesh.UpdateCombinedMesh();
        }

        internal static XRPass Create(XRPassCreateInfo createInfo)
        {
            XRPass pass = GenericPool<XRPass>.Get();

            pass.m_Views.Clear();
            pass.multipassId = createInfo.multipassId;
            pass.cullingPassId = createInfo.cullingPassId;
            pass.cullingParams = createInfo.cullingParameters;
            pass.copyDepth = createInfo.copyDepth;
            pass.renderTarget = new RenderTargetIdentifier(createInfo.renderTarget, 0, CubemapFace.Unknown, -1);
            pass.renderTargetDesc = createInfo.renderTargetDesc;

            pass.m_OcclusionMesh.SetMaterial(createInfo.occlusionMeshMaterial);

            return pass;
        }

        internal static void Release(XRPass xrPass)
        {
            GenericPool<XRPass>.Release(xrPass);
        }

        internal void AddView(XRView xrView)
        {
            if (m_Views.Count < TextureXR.slices)
            {
                m_Views.Add(xrView);
            }
            else
            {
                throw new NotImplementedException($"Invalid XR setup for single-pass, trying to add too many views! Max supported: {TextureXR.slices}");
            }
        }
    }
}

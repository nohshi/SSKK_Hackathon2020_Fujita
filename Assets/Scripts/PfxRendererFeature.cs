using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PfxRendererFeature : ScriptableRendererFeature
{
    private PfxRenderPass pfxRenderPass;

    private ComputeCurvDirPass computeCurvDirPass;
    private RenderTargetHandle computeCurvDirPassRT;

    private CameraNormalTexturePass cameraNormalTexturePass;
    private RenderTargetHandle cameraNormalTextureRT;

    public override void Create()
    {
        cameraNormalTexturePass = new CameraNormalTexturePass(RenderQueueRange.opaque, -1);
        cameraNormalTexturePass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses;
        cameraNormalTextureRT.Init(cameraNormalTexturePass.TextureName);

        //自前分 //曲面方向を計算してテクスチャに書き込むパス
        computeCurvDirPass = new ComputeCurvDirPass();
        computeCurvDirPass.renderPassEvent = RenderPassEvent.AfterRenderingPrePasses + 1;
        computeCurvDirPassRT.Init(computeCurvDirPass.TextureName);
        //
        
        pfxRenderPass = new PfxRenderPass();
        pfxRenderPass.renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        var baseDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        baseDescriptor.colorFormat = RenderTextureFormat.ARGBHalf;
        cameraNormalTexturePass.Setup(baseDescriptor, cameraNormalTextureRT);
        renderer.EnqueuePass(cameraNormalTexturePass);

        computeCurvDirPass.Setup(renderer.cameraColorTarget, computeCurvDirPassRT);
        renderer.EnqueuePass(computeCurvDirPass);

        pfxRenderPass.SetRenderTarget(renderer.cameraColorTarget, cameraNormalTextureRT);
        renderer.EnqueuePass(pfxRenderPass);
    }
}


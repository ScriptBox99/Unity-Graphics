using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace UnityEditor.Rendering.Universal
{
    class UniversalGlobalSettingsPanelProvider : RenderPipelineGlobalSettingsProvider<
        UniversalRenderPipeline,
        UniversalRenderPipelineGlobalSettings,
        SerializedUniversalRenderPipelineGlobalSettings>
    {
        public UniversalGlobalSettingsPanelProvider(string v, SettingsScope project)
            : base(v, project)
        {
        }

        [SettingsProvider]
        public static SettingsProvider CreateSettingsProvider()
        {
            return new UniversalGlobalSettingsPanelProvider("Project/Graphics/URP Global Settings", SettingsScope.Project)
            {
                keywords = SettingsProvider.GetSearchKeywordsFromGUIContentProperties<UniversalRenderPipelineGlobalSettingsUI.Styles>().ToArray(),
            };
        }

        #region RenderPipelineGlobalSettingsProvider

        public override void OnTitleBarGUI()
        {
            if (GUILayout.Button(CoreEditorStyles.iconHelp, CoreEditorStyles.iconHelpStyle))
                Help.BrowseURL(Documentation.GetPageLink("URP-Global-Settings"));
        }

        protected override void Clone(UniversalRenderPipelineGlobalSettings src, bool activateAsset)
        {
            UniversalGlobalSettingsCreator.Clone(src, activateAsset: activateAsset);
        }

        protected override void Create(bool useProjectSettingsFolder, bool activateAsset)
        {
            UniversalGlobalSettingsCreator.Create(useProjectSettingsFolder: true, activateAsset: true);
        }

        protected override void Ensure()
        {
            UniversalRenderPipelineGlobalSettings.Ensure();
        }

        protected override void Refresh(ref UniversalRenderPipelineGlobalSettings settingsSerialized, ref ISerializedRenderPipelineGlobalSettings serializedSettings)
        {
            settingsSerialized = UniversalRenderPipelineGlobalSettings.Ensure();
            var serializedObject = new SerializedObject(settingsSerialized);
            serializedSettings = new SerializedUniversalRenderPipelineGlobalSettings(serializedObject);
        }

        protected override void UpdateGraphicsSettings(UniversalRenderPipelineGlobalSettings newSettings)
        {
            UniversalRenderPipelineGlobalSettings.UpdateGraphicsSettings(newSettings);
        }
        #endregion
    }
}

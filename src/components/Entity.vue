<template>
  <sqid-bars>
    <template v-slot:mainbar>
      <div v-if="banner" style="overflow: hidden;">
        <sqid-image :file="banner" width="850" />
      </div>
      <h1><span>{{ label }}</span></h1>
      <div id="aliases">
        <ul class="list-inline">
          <li class="list-inline-item" v-for="alias in aliases" :key="alias.value">{{ alias }}</li>
        </ul>
      </div>
      <div id="description">{{ description }}</div>
      <sqid-collapsible-card :header="'Works by'" :id="'yourId'" narrow>
        <b-card-body>
          <ul>
            <li v-for="(work, index) in works" :key="index" v-if="work.title">
              {{ work.title }}
            </li>
          </ul>
        </b-card-body>
      </sqid-collapsible-card>
    </template>
    <template v-slot:sidebar>
      <sqid-image :file="images[0]" width="260" v-if="images && images[0]" />
      <sqid-collapsible-card :header="$t('entity.links')" :id="links" narrow>
        <b-card-body>
          <table class="table table-striped table-sm narrow">
            <tbody>
              <tr v-for="(link, lidx) in links" :key="lidx">
                <th><a :href="link.url" target="_blank">{{ link.label }}</a></th>
              </tr>
            </tbody>
          </table>
        </b-card-body>
      </sqid-collapsible-card>
    </template>
  </sqid-bars>
</template>

<script lang="ts">
import { Component, Prop, Watch, Vue } from 'vue-property-decorator'
import { Getter, Action } from 'vuex-class'
import { EntityId, EntityKind, QualifiedEntityValue, WBDatatype } from '@/api/types'
import { relatedEntityIds, parseEntityId, idsFromQualifiedEntity, isPropertyId } from '@/api/wikidata'
import { fetchSvdeAgentId, fetchWorks } from '@/api/apiService';

@Component
export default class Entity extends Vue {
  @Prop({ required: true }) private entityId!: string
  @Action private getEntityData: any
  @Action private getPropertyDatatypes: any
  @Action private requestLabels: any
  @Getter private getImages: any
  @Getter private getBanner: any
  @Getter private getHomepage: any
  @Getter private getWikidataUrl: any
  @Getter private getWikipediaUrl: any
  @Getter private getReasonatorUrl: any
  @Getter private getValuesForProperty!: (entityId: EntityId, propertyId: EntityId) => QualifiedEntityValue[] | null
  @Getter private getPropertyDatatype!: (entityId: EntityId) => WBDatatype | undefined
  private linkUrls: Array<{ url: string, label: any }> = []
  private label = this.entityId
  private aliases: string[] = []
  private description: string | null = null
  private images: string[] | null = null
  private banner: string | null = null
  private kind: EntityKind | null = null
  private propertyDatatype: WBDatatype | null = null
  private superProperties: QualifiedEntityValue[] = []
  private superClasses: QualifiedEntityValue[] = []
  private instanceClasses: QualifiedEntityValue[] = []
  private works: any[] = []; // Add a new property to store the works

  private async updateEntityData() {
    const { kind } = parseEntityId(this.entityId)
    this.kind = kind
    const data = await this.getEntityData(this.entityId)
    this.label = data.label || this.entityId
    this.aliases = data.aliases
    this.description = data.description
    const related = relatedEntityIds(data.claims)
    this.requestLabels({entityIds: Array.from(related)})
    const properties = Array.from(related).map(entityId => entityId as EntityId).filter(isPropertyId);
    this.getPropertyDatatypes(properties)
    this.images = this.getImages(this.entityId)
    this.banner = this.getBanner(this.entityId)
    if (kind === 'property') {
      this.propertyDatatype = this.getPropertyDatatype(this.entityId) || null
      this.superProperties = this.getValuesForProperty(this.entityId, 'P1647') || []
    }
    this.superClasses = this.getValuesForProperty(this.entityId, 'P279') || []
    this.instanceClasses = this.getValuesForProperty(this.entityId, 'P31') || []
    const entityIds = ['P1647', 'P279', 'P31'].concat(
      ...this.superProperties.map(idsFromQualifiedEntity),
      ...this.superClasses.map(idsFromQualifiedEntity),
      ...this.instanceClasses.map(idsFromQualifiedEntity))
    this.requestLabels({ entityIds })
  }

  private async displayWorks() {
  const svdeAgentId = await fetchSvdeAgentId(this.entityId);
  const response = await fetchWorks(svdeAgentId);
  this.works = response.data.person.opuses.resources;
}

  private async created() {
    this.updateEntityData()
    this.updateLinks()
    this.displayWorks() // Call the new method here
  }

  @Watch('entityId')
  private onEntityIdChanged() {
    this.updateEntityData()
    this.displayWorks() // And here
  }

  private updateLinks() {
    const urls: Array<{ url: string, label: any }> =
      [{ url: this.getWikidataUrl(this.entityId),
         label: this.$t('entity.wikidataLink'),
       }]
    const homepage = this.getHomepage(this.entityId)
    if (homepage !== null) {
      urls.push({ url: homepage,
                  label: this.$t('entity.homepageLink'),
                })
    }
    const wikipedia = this.getWikipediaUrl(this.entityId)
    if (wikipedia !== null) {
      urls.push({ url: wikipedia,
                  label: this.$t('entity.wikipediaLink'),
                })
    }
    urls.push({ url: this.getReasonatorUrl(this.entityId),
                label: this.$t('entity.reasonatorLink'),
              })
    this.linkUrls = urls
  }

  private get wikidata() {
    return this.getWikidataUrl(this.entityId)
  }

  private get links() {
    return this.linkUrls
  }
}
</script>
<style lang="less" scoped>
#aliases {
  margin-top: -10px;
  margin-bottom: 0px;
  color: #999999;
}

#aliases ul {
  margin-top: -10px;
  margin-bottom: 0px;
}

#aliases ul li {
  margin-top: -10px;
  padding-right: 0px;
}

#aliases ul li::after {
  content: " |";
}

#aliases ul li:last-child::after {
  content: "";
}

#description {
  font-size: 1.3em;
}

table {
  table-layout: fixed;
  margin-bottom: 0px !important;

  &:not(.narrow) th {
    width: 25%;
  }
}

.card-body {
  padding: 0 0;
}

.four-lines {
  overflow: auto;
  max-height: 6em;
}

.comma-separated {
  display: inline;
  list-style: none;
  padding: 0;

  li {
    display: inline;
  }

  li::after {
    content: ", ";
  }

  li:last-child::after {
    content: "";
  }

.badge {
  margin-left: .25em;
  margin-right: .05em;
}
}
</style>